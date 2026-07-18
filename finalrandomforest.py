import pickle
import numpy as np
import cv2
import os
import json
import csv
import glob
import shutil
import threading
from datetime import datetime, timezone
from flask import Flask, request, jsonify
from flask_cors import CORS
from skimage.feature import graycomatrix, graycoprops
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

with open(os.path.join(BASE_DIR, 'rf_model.pkl'), 'rb') as f:
    model = pickle.load(f)

with open(os.path.join(BASE_DIR, 'label_encoder.pkl'), 'rb') as f:
    le = pickle.load(f)

IMG_SIZE = (256, 256)

# ---------------------------------------------------------------------------
# Dynamic class management (training_images/, classes.json, dataset_master.csv,
# rf_addon_*.pkl). Everything below is additive and does not alter the
# original predict/health behaviour above.
# ---------------------------------------------------------------------------

TRAINING_IMAGES_DIR = os.path.join(BASE_DIR, 'training_images')
CLASSES_JSON_PATH = os.path.join(BASE_DIR, 'classes.json')
DATASET_MASTER_CSV = os.path.join(BASE_DIR, 'dataset_master.csv')
FEATURE_COLUMNS = ['contrast', 'correlation', 'energy', 'homogeneity',
                    'h_mean', 'h_std', 's_mean', 's_std', 'v_mean', 'v_std']

MIN_IMAGES_PER_CLASS = 20
MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024
ADDON_CONFIDENCE_THRESHOLD = 0.70

classes_json_lock = threading.Lock()
training_lock = threading.Lock()
training_status = {
    'is_training': False,
    'class_name': None,
    'current_step': None,
    'progress': 0.0,
    'error': None,
    'result': None,
}

# Cache of loaded addon models keyed by filename -> (mtime, label, sklearn model).
_addon_models_cache = {}
_addon_models_cache_lock = threading.Lock()


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _init_storage():
    os.makedirs(TRAINING_IMAGES_DIR, exist_ok=True)
    if not os.path.exists(CLASSES_JSON_PATH):
        with classes_json_lock:
            if not os.path.exists(CLASSES_JSON_PATH):
                payload = {
                    'classes': list(le.classes_),
                    'last_updated': _now_iso(),
                }
                with open(CLASSES_JSON_PATH, 'w') as f:
                    json.dump(payload, f, indent=2)


def _read_classes_json():
    with classes_json_lock:
        try:
            with open(CLASSES_JSON_PATH, 'r') as f:
                data = json.load(f)
            if not isinstance(data, dict) or 'classes' not in data:
                raise ValueError('classes.json missing "classes" key')
            return data
        except (FileNotFoundError, json.JSONDecodeError, ValueError, OSError) as e:
            # classes.json missing or corrupted (e.g. a half-written file from
            # a crashed request) — rebuild from the model's own baked-in
            # classes rather than 500ing on every /model_status call. Any
            # dynamically-added class that only existed in the corrupted
            # file is lost, but that's strictly better than the endpoint
            # being permanently broken.
            print(f'[WARN] classes.json unreadable ({e}), rebuilding from label_encoder classes.')
            payload = {
                'classes': list(le.classes_),
                'last_updated': _now_iso(),
            }
            with open(CLASSES_JSON_PATH, 'w') as f:
                json.dump(payload, f, indent=2)
            return payload


def _write_classes_json(classes_list):
    with classes_json_lock:
        payload = {
            'classes': classes_list,
            'last_updated': _now_iso(),
        }
        with open(CLASSES_JSON_PATH, 'w') as f:
            json.dump(payload, f, indent=2)


def _update_training_status(**kwargs):
    with training_lock:
        training_status.update(kwargs)


def _get_training_status_snapshot():
    with training_lock:
        return dict(training_status)


def _center_crop_square(img, ratio=0.80):
    """
    Mirrors ClassificationRepositoryImpl._cropToOverlayArea() on the Flutter
    side: every image sent to /predict is first cropped to a centered square
    covering `ratio` of the shorter side. Training photos uploaded via
    /add_class are NOT pre-cropped by the app, so without this step the
    addon model would learn on full-frame photos while inference always
    sees a center-cropped square — a framing mismatch that tanks addon
    confidence on real predictions.
    """
    h, w = img.shape[:2]
    crop_size = int(min(h, w) * ratio)
    x = (w - crop_size) // 2
    y = (h - crop_size) // 2
    return img[y:y + crop_size, x:x + crop_size]


def _append_features_to_dataset(class_name, feature_rows):
    file_exists = os.path.exists(DATASET_MASTER_CSV)
    with open(DATASET_MASTER_CSV, 'a', newline='') as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(FEATURE_COLUMNS + ['label'])
        for row in feature_rows:
            writer.writerow(list(row) + [class_name])


def _read_dataset_master():
    """Returns (X, y) numpy arrays from dataset_master.csv, or (None, None) if absent."""
    if not os.path.exists(DATASET_MASTER_CSV):
        return None, None
    X, y = [], []
    with open(DATASET_MASTER_CSV, 'r', newline='') as f:
        reader = csv.reader(f)
        header = next(reader, None)
        for row in reader:
            if not row:
                continue
            X.append([float(v) for v in row[:-1]])
            y.append(row[-1])
    if not X:
        return None, None
    return np.array(X), np.array(y)


def _train_addon_model(class_name):
    """
    Trains a small binary RandomForest that tells apart `class_name` from
    every other class accumulated so far in dataset_master.csv.
    Returns (model_or_None, accuracy_or_None, note).
    """
    X, y = _read_dataset_master()
    if X is None:
        return None, None, 'Tidak ada data fitur untuk melatih model addon.'

    y_binary = np.array([1 if label == class_name else 0 for label in y])
    positive_count = int(y_binary.sum())
    negative_count = int(len(y_binary) - positive_count)

    if positive_count < 2:
        return None, None, 'Fitur kelas baru tidak cukup untuk melatih model.'

    if negative_count == 0:
        # First class ever added — nothing to contrast against yet. The
        # addon model can't be trained meaningfully; classes.json is still
        # updated so the class is marked active once a second class exists.
        return None, None, 'Belum ada kelas pembanding, model addon menunggu kelas berikutnya.'

    stratify = y_binary if min(positive_count, negative_count) >= 2 else None
    X_train, X_test, y_train, y_test = train_test_split(
        X, y_binary, test_size=0.2, random_state=42, stratify=stratify
    )

    clf = RandomForestClassifier(n_estimators=100, random_state=42)
    clf.fit(X_train, y_train)

    if len(X_test) > 0:
        accuracy = float(accuracy_score(y_test, clf.predict(X_test)))
    else:
        accuracy = float(accuracy_score(y_train, clf.predict(X_train)))

    return clf, accuracy, None


def _save_addon_model(class_name, clf):
    safe_name = secure_filename(class_name)
    path = os.path.join(BASE_DIR, f'rf_addon_{safe_name}.pkl')
    with open(path, 'wb') as f:
        pickle.dump({'label': class_name, 'model': clf, 'features': FEATURE_COLUMNS}, f)
    return path


def _load_addon_models():
    """Loads every rf_addon_*.pkl in BASE_DIR, caching by file mtime."""
    loaded = []
    for path in glob.glob(os.path.join(BASE_DIR, 'rf_addon_*.pkl')):
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        with _addon_models_cache_lock:
            cached = _addon_models_cache.get(path)
            if cached and cached[0] == mtime:
                loaded.append((cached[1], cached[2]))
                continue
        try:
            with open(path, 'rb') as f:
                data = pickle.load(f)
            label = data['label']
            clf = data['model']
        except Exception:
            continue
        with _addon_models_cache_lock:
            _addon_models_cache[path] = (mtime, label, clf)
        loaded.append((label, clf))
    return loaded


def _run_add_class_job(class_name, image_paths, description, symptoms, treatment):
    try:
        _update_training_status(
            is_training=True, class_name=class_name, error=None, result=None,
            current_step='Mengekstraksi fitur gambar', progress=0.2,
        )

        feature_rows = []
        for path in image_paths:
            img = cv2.imread(path)
            if img is None:
                continue
            img = _center_crop_square(img)
            feature_rows.append(extract_combined_features(img))

        if len(feature_rows) < MIN_IMAGES_PER_CLASS:
            _update_training_status(
                is_training=False, error='Fitur valid kurang dari minimum yang diperlukan.',
                current_step='Gagal', progress=0.0,
            )
            return

        _append_features_to_dataset(class_name, feature_rows)

        _update_training_status(current_step='Melatih ulang model', progress=0.6)
        clf, accuracy, note = _train_addon_model(class_name)
        if clf is not None:
            _save_addon_model(class_name, clf)
            with _addon_models_cache_lock:
                # Force a reload on next predict call.
                _addon_models_cache.clear()

        _update_training_status(current_step='Menyimpan data penyakit', progress=0.9)
        current = _read_classes_json()
        classes_list = current.get('classes', [])
        if class_name not in classes_list:
            classes_list.append(class_name)
        _write_classes_json(classes_list)

        _update_training_status(
            is_training=False,
            current_step='Selesai',
            progress=1.0,
            error=None,
            result={
                'class_name': class_name,
                'accuracy': accuracy,
                'total_classes': len(classes_list),
                'classes': classes_list,
                'note': note,
            },
        )
    except Exception as e:
        _update_training_status(
            is_training=False, error=str(e), current_step='Gagal', progress=0.0,
        )


def auto_crop_leaf_v3(img):
    """
    Auto-crop menggunakan GrabCut, dengan resize awal untuk mempercepat proses.
    """
    h_orig, w_orig = img.shape[:2]

    max_dim = 600
    scale = max_dim / max(h_orig, w_orig)
    if scale < 1:
        img_small = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    else:
        img_small = img.copy()
        scale = 1.0

    h_small, w_small = img_small.shape[:2]

    mask = np.zeros((h_small, w_small), np.uint8)
    margin_x = int(w_small * 0.08)
    margin_y = int(h_small * 0.05)
    rect = (margin_x, margin_y, w_small - 2 * margin_x, h_small - 2 * margin_y)

    bgdModel = np.zeros((1, 65), np.float64)
    fgdModel = np.zeros((1, 65), np.float64)

    try:
        cv2.grabCut(img_small, mask, rect, bgdModel, fgdModel, 5, cv2.GC_INIT_WITH_RECT)
    except Exception:
        return img

    mask_final = np.where((mask == 2) | (mask == 0), 0, 1).astype('uint8')
    kernel = np.ones((10, 10), np.uint8)
    mask_clean = cv2.morphologyEx(mask_final * 255, cv2.MORPH_CLOSE, kernel)
    mask_clean = cv2.morphologyEx(mask_clean, cv2.MORPH_OPEN, kernel)

    contours, _ = cv2.findContours(mask_clean, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if contours:
        largest = max(contours, key=cv2.contourArea)
        area_ratio = cv2.contourArea(largest) / (h_small * w_small)

        if area_ratio > 0.10:
            x, y, w, h = cv2.boundingRect(largest)
            pad = 15
            x1, y1 = max(0, x - pad), max(0, y - pad)
            x2, y2 = min(w_small, x + w + pad), min(h_small, y + h + pad)

            x1_orig, y1_orig = int(x1 / scale), int(y1 / scale)
            x2_orig, y2_orig = int(x2 / scale), int(y2 / scale)

            return img[y1_orig:y2_orig, x1_orig:x2_orig]

    return img


def extract_combined_features(img):
    """
    Ekstraksi fitur gabungan: GLCM + Warna HSV, dengan auto-crop GrabCut.
    """
    img_cropped = auto_crop_leaf_v3(img)
    img_resized = cv2.resize(img_cropped, IMG_SIZE)
    gray = cv2.cvtColor(img_resized, cv2.COLOR_BGR2GRAY)

    glcm = graycomatrix(
        gray, distances=[1],
        angles=[0, np.pi / 4, np.pi / 2, 3 * np.pi / 4],
        levels=256, symmetric=True, normed=True
    )
    contrast = graycoprops(glcm, 'contrast').mean()
    correlation = graycoprops(glcm, 'correlation').mean()
    energy = graycoprops(glcm, 'energy').mean()
    homogeneity = graycoprops(glcm, 'homogeneity').mean()

    hsv = cv2.cvtColor(img_resized, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)
    h_mean, h_std = h.mean(), h.std()
    s_mean, s_std = s.mean(), s.std()
    v_mean, v_std = v.mean(), v.std()

    return [contrast, correlation, energy, homogeneity,
            h_mean, h_std, s_mean, s_std, v_mean, v_std]


_init_storage()


@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({'is_success': False, 'error_message': 'No image provided',
                        'category': '', 'confidence': 0.0}), 400

    file = request.files['image']
    file_bytes = np.frombuffer(file.read(), np.uint8)
    img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

    if img is None:
        return jsonify({'is_success': False, 'error_message': 'Invalid image format',
                        'category': '', 'confidence': 0.0}), 400
    try:
        features = np.array(extract_combined_features(img)).reshape(1, -1)
        pred = model.predict(features)
        proba = model.predict_proba(features)
        confidence = float(np.max(proba))
        category = le.inverse_transform(pred)[0]

        # Check dynamically-added addon classes: if any of them is more
        # confident than the main model about this being their class,
        # override the result with that addon's prediction.
        best_addon_label = None
        best_addon_confidence = 0.0
        for label, clf in _load_addon_models():
            try:
                addon_proba = clf.predict_proba(features)
                positive_index = list(clf.classes_).index(1)
                addon_confidence = float(addon_proba[0][positive_index])
            except Exception:
                continue
            if addon_confidence > ADDON_CONFIDENCE_THRESHOLD and addon_confidence > best_addon_confidence:
                best_addon_label = label
                best_addon_confidence = addon_confidence

        if best_addon_label is not None:
            category = best_addon_label
            confidence = best_addon_confidence

        return jsonify({'is_success': True, 'category': category,
                        'confidence': confidence, 'error_message': None})
    except Exception as e:
        return jsonify({'is_success': False, 'error_message': str(e),
                        'category': '', 'confidence': 0.0}), 500


@app.route('/model_status', methods=['GET'])
def model_status():
    data = _read_classes_json()
    classes_list = data.get('classes', [])
    return jsonify({
        'status': 'ok',
        'total_classes': len(classes_list),
        'classes': classes_list,
        'last_updated': data.get('last_updated'),
    })


@app.route('/training_status', methods=['GET'])
def training_status_endpoint():
    return jsonify(_get_training_status_snapshot())


@app.route('/add_class', methods=['POST'])
def add_class():
    class_name = request.form.get('class_name', '').strip()
    description = request.form.get('description', '').strip()
    symptoms = request.form.get('symptoms', '').strip()
    treatment = request.form.get('treatment', '').strip()
    images = request.files.getlist('images')

    if not class_name:
        return jsonify({'is_success': False, 'error_message': 'Nama kelas wajib diisi'}), 400
    if not description or not symptoms or not treatment:
        return jsonify({'is_success': False,
                        'error_message': 'Deskripsi, gejala, dan penanganan wajib diisi'}), 400

    existing_classes = _read_classes_json().get('classes', [])
    if any(c.strip().lower() == class_name.lower() for c in existing_classes):
        return jsonify({'is_success': False,
                        'error_message': f"Nama penyakit '{class_name}' sudah ada dalam sistem."}), 400

    if len(images) < MIN_IMAGES_PER_CLASS:
        return jsonify({'is_success': False,
                        'error_message': f'Minimal {MIN_IMAGES_PER_CLASS} foto diperlukan'}), 400

    if training_status['is_training']:
        return jsonify({'is_success': False,
                        'error_message': 'Proses training lain sedang berjalan, coba lagi nanti.'}), 409

    safe_name = secure_filename(class_name)
    class_dir = os.path.join(TRAINING_IMAGES_DIR, safe_name)
    os.makedirs(class_dir, exist_ok=True)

    saved_paths = []
    for idx, image_file in enumerate(images):
        file_bytes = image_file.read()
        if len(file_bytes) > MAX_IMAGE_SIZE_BYTES:
            continue
        file_array = np.frombuffer(file_bytes, np.uint8)
        img = cv2.imdecode(file_array, cv2.IMREAD_COLOR)
        if img is None:
            continue
        out_path = os.path.join(class_dir, f'{safe_name}_{idx:03d}.jpg')
        cv2.imwrite(out_path, img)
        saved_paths.append(out_path)

    if len(saved_paths) < MIN_IMAGES_PER_CLASS:
        return jsonify({'is_success': False,
                        'error_message': f'Hanya {len(saved_paths)} foto valid diterima, minimal {MIN_IMAGES_PER_CLASS} diperlukan'}), 400

    _update_training_status(
        is_training=True, class_name=class_name, error=None, result=None,
        current_step='Mengunggah foto ke server', progress=0.1,
    )

    thread = threading.Thread(
        target=_run_add_class_job,
        args=(class_name, saved_paths, description, symptoms, treatment),
        daemon=True,
    )
    thread.start()

    return jsonify({
        'is_success': True,
        'message': f"Kelas '{class_name}' sedang diproses dan model sedang dilatih ulang.",
        'class_name': class_name,
        'total_images_received': len(saved_paths),
    })


@app.route('/remove_class', methods=['POST', 'DELETE'])
def remove_class():
    class_name = (request.form.get('class_name')
                  or (request.get_json(silent=True) or {}).get('class_name')
                  or '').strip()

    if not class_name:
        return jsonify({'is_success': False, 'error_message': 'Nama kelas wajib diisi'}), 400

    # The 6 original classes are baked into rf_model.pkl itself — removing
    # them from classes.json wouldn't stop the main model from predicting
    # them, so we refuse to pretend they're gone.
    if any(c.strip().lower() == class_name.lower() for c in le.classes_):
        return jsonify({'is_success': False,
                        'error_message': f"'{class_name}' adalah kelas bawaan model utama dan tidak bisa dihapus."}), 403

    if training_status['is_training'] and (training_status.get('class_name') or '').lower() == class_name.lower():
        return jsonify({'is_success': False,
                        'error_message': 'Kelas ini sedang dalam proses training, coba lagi setelah selesai.'}), 409

    current = _read_classes_json()
    classes_list = current.get('classes', [])
    matching = [c for c in classes_list if c.strip().lower() == class_name.lower()]
    if not matching:
        return jsonify({'is_success': False,
                        'error_message': f"Kelas '{class_name}' tidak ditemukan di model."}), 404

    remaining_classes = [c for c in classes_list if c not in matching]
    _write_classes_json(remaining_classes)

    # Drop every row for this label from dataset_master.csv so it stops
    # being used as positive/negative data for future addon training.
    if os.path.exists(DATASET_MASTER_CSV):
        X, y = _read_dataset_master()
        if X is not None:
            keep_mask = [label != matching[0] for label in y]
            with open(DATASET_MASTER_CSV, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(FEATURE_COLUMNS + ['label'])
                for row, label, keep in zip(X, y, keep_mask):
                    if keep:
                        writer.writerow(list(row) + [label])

    safe_name = secure_filename(class_name)

    addon_path = os.path.join(BASE_DIR, f'rf_addon_{safe_name}.pkl')
    if os.path.exists(addon_path):
        os.remove(addon_path)
        with _addon_models_cache_lock:
            _addon_models_cache.pop(addon_path, None)

    class_images_dir = os.path.join(TRAINING_IMAGES_DIR, safe_name)
    if os.path.isdir(class_images_dir):
        shutil.rmtree(class_images_dir)

    return jsonify({
        'is_success': True,
        'message': f"Kelas '{class_name}' berhasil dihapus dari model.",
        'total_classes': len(remaining_classes),
        'classes': remaining_classes,
    })


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'classes': list(le.classes_)})


if __name__ == '__main__':
    app.run(debug=False)