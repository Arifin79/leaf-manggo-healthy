import pickle
import numpy as np
import cv2
import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from skimage.feature import graycomatrix, graycoprops

app = Flask(__name__)
CORS(app)

# Ambil path folder saat ini agar file .pkl terbaca dengan benar
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Load model dan label encoder
with open(os.path.join(BASE_DIR, 'rf_model.pkl'), 'rb') as f:
    model = pickle.load(f)

with open(os.path.join(BASE_DIR, 'label_encoder.pkl'), 'rb') as f:
    le = pickle.load(f)

IMG_SIZE = (256, 256)

def extract_glcm_features(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, IMG_SIZE)

    glcm = graycomatrix(
        gray,
        distances=[1],
        angles=[0, np.pi/4, np.pi/2, 3*np.pi/4],
        levels=256,
        symmetric=True,
        normed=True
    )

    contrast    = graycoprops(glcm, 'contrast').mean()
    correlation = graycoprops(glcm, 'correlation').mean()
    energy      = graycoprops(glcm, 'energy').mean()
    homogeneity = graycoprops(glcm, 'homogeneity').mean()

    return [contrast, correlation, energy, homogeneity]

@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({'is_success': False, 'error_message': 'No image provided'}), 400

    file = request.files['image']
    file_bytes = np.frombuffer(file.read(), np.uint8)
    img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

    if img is None:
        return jsonify({'is_success': False, 'error_message': 'Invalid image format'}), 400

    try:
        features = extract_glcm_features(img)
        features_arr = np.array(features).reshape(1, -1)

        pred       = model.predict(features_arr)
        proba      = model.predict_proba(features_arr)
        confidence = float(np.max(proba))
        category   = le.inverse_transform(pred)[0]

        return jsonify({
            'is_success':    True,
            'category':      category,
            'confidence':    confidence,
            'error_message': None
        })

    except Exception as e:
        return jsonify({'is_success': False, 'error_message': str(e)}), 500

@app.route('/', methods=['GET'])
def index():
    return jsonify({'message': 'API Leaf Healthy Manggo is running!'})

if __name__ == '__main__':
    app.run(debug=False)
