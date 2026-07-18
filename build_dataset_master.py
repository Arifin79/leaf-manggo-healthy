"""
One-off script to (re)build dataset_master.csv from the existing training
photos of the 6 mango-leaf disease classes, and optionally push the result
to PythonAnywhere so /add_class on finalrandomforest.py has a real dataset
to compare new classes against.

Run once, locally or in Google Colab:

    python build_dataset_master.py --dataset-dir /path/to/dataset

Expected folder layout (one subfolder per class, any image inside it):

    dataset/
        Anthracnose/*.jpg
        Die Back/*.jpg
        Gall Midge/*.jpg
        Powdery Mildew/*.jpg
        Sooty Mould/*.jpg
        Daun Sehat/*.jpg

Unlike finalrandomforest.py, extract_combined_features() here skips the
GrabCut auto-crop step (auto_crop_leaf_v3) and resizes the raw frame
straight to 256x256 before GLCM/HSV extraction — GrabCut is slow and,
for a one-off bulk dataset build, not worth the runtime cost.

The script is resumable: it periodically checkpoints progress to
progress.json (every 50 photos) and, on a fresh invocation, skips any
class whose label is already fully present in dataset_master.csv or
already marked completed in progress.json, picking back up mid-class
from the last checkpointed photo if it was interrupted there.
"""

import argparse
import csv
import glob
import json
import os
import sys
from datetime import datetime, timezone

import cv2
import numpy as np
from skimage.feature import graycomatrix, graycoprops

CLASS_NAMES = [
    'Anthracnose',
    'Die Back',
    'Gall Midge',
    'Powdery Mildew',
    'Sooty Mould',
    'Daun Sehat',
]

FEATURE_COLUMNS = ['contrast', 'correlation', 'energy', 'homogeneity',
                    'h_mean', 'h_std', 's_mean', 's_std', 'v_mean', 'v_std']

IMG_SIZE = (256, 256)
IMAGE_EXTENSIONS = ('*.jpg', '*.jpeg', '*.png', '*.JPG', '*.JPEG', '*.PNG')


# ---------------------------------------------------------------------------
# Feature extraction — GLCM + HSV, same math as finalrandomforest.py but
# without the GrabCut auto-crop step (see module docstring for why).
# ---------------------------------------------------------------------------

def extract_combined_features(img):
    """Ekstraksi fitur gabungan: GLCM + Warna HSV, resize langsung tanpa auto-crop."""
    img_resized = cv2.resize(img, IMG_SIZE)
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


# ---------------------------------------------------------------------------
# Dataset building
# ---------------------------------------------------------------------------

def find_class_dir(dataset_dir, class_name):
    """Matches a class folder case-insensitively (Colab uploads often mangle case)."""
    direct = os.path.join(dataset_dir, class_name)
    if os.path.isdir(direct):
        return direct
    for entry in os.listdir(dataset_dir):
        if entry.strip().lower() == class_name.strip().lower():
            candidate = os.path.join(dataset_dir, entry)
            if os.path.isdir(candidate):
                return candidate
    return None


def list_images(class_dir):
    paths = []
    for pattern in IMAGE_EXTENSIONS:
        paths.extend(glob.glob(os.path.join(class_dir, pattern)))
    return sorted(set(paths))


# ---------------------------------------------------------------------------
# Resume support (progress.json + dataset_master.csv inspection)
# ---------------------------------------------------------------------------

CHECKPOINT_EVERY = 50


def default_progress():
    return {'completed_classes': [], 'current_class': None, 'processed_images': [], 'updated_at': None}


def load_progress(progress_path):
    if os.path.exists(progress_path):
        try:
            with open(progress_path, 'r') as f:
                data = json.load(f)
            return {**default_progress(), **data}
        except (json.JSONDecodeError, OSError):
            print(f"[WARN] progress.json rusak/tidak terbaca, mulai ulang tracking progress: {progress_path}")
    return default_progress()


def save_progress(progress_path, progress):
    progress['updated_at'] = datetime.now(timezone.utc).isoformat()
    with open(progress_path, 'w') as f:
        json.dump(progress, f, indent=2)


def read_existing_labels(csv_path):
    """Labels already fully written to dataset_master.csv from a prior run."""
    if not os.path.exists(csv_path):
        return set()
    labels = set()
    with open(csv_path, 'r', newline='') as f:
        reader = csv.reader(f)
        next(reader, None)  # header
        for row in reader:
            if row:
                labels.add(row[-1])
    return labels


def build_dataset(dataset_dir, output_path, class_names=CLASS_NAMES, progress_path=None):
    if progress_path is None:
        progress_path = os.path.join(os.path.dirname(os.path.abspath(output_path)), 'progress.json')

    progress = load_progress(progress_path)
    completed_classes = set(progress['completed_classes']) | read_existing_labels(output_path)

    csv_exists = os.path.exists(output_path)
    summary = {}
    total_written = 0

    with open(output_path, 'a' if csv_exists else 'w', newline='') as f:
        writer = csv.writer(f)
        if not csv_exists:
            writer.writerow(FEATURE_COLUMNS + ['label'])

        for class_name in class_names:
            if class_name in completed_classes:
                print(f"[SKIP] Kelas '{class_name}' sudah lengkap di {output_path}, dilewati.")
                summary[class_name] = 'already done'
                continue

            class_dir = find_class_dir(dataset_dir, class_name)
            if class_dir is None:
                print(f"[SKIP] Folder untuk kelas '{class_name}' tidak ditemukan di {dataset_dir}")
                summary[class_name] = 0
                continue

            image_paths = list_images(class_dir)

            if progress['current_class'] == class_name:
                already_processed = set(progress['processed_images'])
                print(f"[{class_name}] melanjutkan dari checkpoint: {len(already_processed)} foto sudah diproses.")
            else:
                already_processed = set()
                progress['current_class'] = class_name
                progress['processed_images'] = []

            remaining_paths = [p for p in image_paths if p not in already_processed]
            print(f"[{class_name}] {len(image_paths)} foto total, {len(remaining_paths)} tersisa untuk diproses.")

            extracted = 0
            for path in remaining_paths:
                img = cv2.imread(path)
                if img is None:
                    print(f"  - lewati (gagal dibaca): {path}")
                    continue
                try:
                    features = extract_combined_features(img)
                except Exception as e:
                    print(f"  - lewati (gagal ekstraksi): {path} ({e})")
                    continue

                writer.writerow(features + [class_name])
                f.flush()
                extracted += 1
                total_written += 1
                progress['processed_images'].append(path)

                if len(progress['processed_images']) % CHECKPOINT_EVERY == 0:
                    save_progress(progress_path, progress)
                    print(f"  ... checkpoint disimpan ({len(progress['processed_images'])}/{len(image_paths)} foto kelas ini)")

            summary[class_name] = extracted
            print(f"[{class_name}] selesai: {extracted} baris fitur baru")

            progress['completed_classes'] = list(set(progress['completed_classes']) | {class_name})
            progress['current_class'] = None
            progress['processed_images'] = []
            save_progress(progress_path, progress)

    print(f"\nSelesai. {total_written} baris fitur baru ditambahkan ke {output_path}")
    print("Ringkasan per kelas:")
    for class_name, count in summary.items():
        print(f"  - {class_name}: {count}")

    return summary


# ---------------------------------------------------------------------------
# Optional upload to PythonAnywhere via its Files API.
# https://www.pythonanywhere.com/api/v0/user/<username>/files/path<path>/
# Requires an API token from the "Account" page on PythonAnywhere.
# ---------------------------------------------------------------------------

def upload_to_pythonanywhere(local_path, username, api_token, remote_path, host='www.pythonanywhere.com'):
    import requests

    url = f'https://{host}/api/v0/user/{username}/files/path{remote_path}/'
    with open(local_path, 'rb') as f:
        response = requests.post(
            url,
            headers={'Authorization': f'Token {api_token}'},
            files={'content': f},
        )

    if response.status_code in (200, 201):
        print(f"Upload berhasil ke {remote_path} (status {response.status_code})")
    else:
        print(f"Upload GAGAL (status {response.status_code}): {response.text}")
        response.raise_for_status()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--dataset-dir', required=True,
                        help='Folder berisi 6 subfolder kelas (Anthracnose, Die Back, dst).')
    parser.add_argument('--output', default='dataset_master.csv',
                        help='Path file csv output (default: dataset_master.csv).')
    parser.add_argument('--progress-file', default=None,
                        help='Path progress.json (default: progress.json di folder --output).')
    parser.add_argument('--upload', action='store_true',
                        help='Upload dataset_master.csv ke PythonAnywhere setelah dibuat.')
    parser.add_argument('--pa-username', default=os.environ.get('PA_USERNAME'),
                        help='Username PythonAnywhere (atau set env PA_USERNAME).')
    parser.add_argument('--pa-token', default=os.environ.get('PA_API_TOKEN'),
                        help='API token PythonAnywhere (atau set env PA_API_TOKEN). Jangan hardcode di script.')
    parser.add_argument('--pa-remote-path', default=os.environ.get('PA_REMOTE_PATH'),
                        help='Path tujuan di server, misal /home/<user>/mysite/dataset_master.csv.')
    parser.add_argument('--pa-host', default='www.pythonanywhere.com',
                        help='Host API PythonAnywhere (default www.pythonanywhere.com; pakai eu.pythonanywhere.com jika akun EU).')
    return parser.parse_args()


def main():
    args = parse_args()

    if not os.path.isdir(args.dataset_dir):
        print(f"Dataset dir tidak ditemukan: {args.dataset_dir}")
        sys.exit(1)

    build_dataset(args.dataset_dir, args.output, progress_path=args.progress_file)

    if args.upload:
        missing = [name for name, value in [
            ('--pa-username', args.pa_username),
            ('--pa-token', args.pa_token),
            ('--pa-remote-path', args.pa_remote_path),
        ] if not value]
        if missing:
            print(f"Tidak bisa upload, parameter berikut belum diisi: {', '.join(missing)}")
            sys.exit(1)
        if not os.path.exists(args.output):
            print("dataset_master.csv tidak dibuat (tidak ada fitur), upload dibatalkan.")
            sys.exit(1)
        upload_to_pythonanywhere(args.output, args.pa_username, args.pa_token, args.pa_remote_path, args.pa_host)


if __name__ == '__main__':
    main()
