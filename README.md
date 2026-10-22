# RetinaScan AI — Diabetic Retinopathy Screening System (SIH 26038)

[![MATLAB](https://img.shields.io/badge/MATLAB-R2024a%2B-blue.svg)](https://www.mathworks.com/)
[![ONNX Runtime](https://img.shields.io/badge/ONNX-Runtime%201.16%2B-orange.svg)](https://onnxruntime.ai/)
[![Python](https://img.shields.io/badge/Python-3.10%2B-green.svg)](https://www.python.org/)
[![Smart India Hackathon](https://img.shields.io/badge/SIH-Problem%2026038-red.svg)](https://sih.gov.in/)

An explainable, fail-closed, multi-model AI tele-screening platform designed for Primary Health Centres (PHCs) in Rural India.

---

## 🌟 Key Highlights

- **Bilateral One-Click Screening (`OD + OS`)**: Automated sequencing of both eyes with smart component caching.
- **Fail-Closed Quality Gate**: Blocks ungradable or blurry retinal captures using Shannon entropy, SNR, and vessel gradient energy.
- **ICDR Clinical Grading Arbitration**: Fuses physical microvascular lesion counts (MA, HE, EX, SE, Bleeding) with **EfficientNet-B0** (`retina_model.onnx`, 43.7 MB) to prevent uncalibrated scratch models from outputting false negatives.
- **Dual Lesion Detectors**: Supports both **YOLO11n** (IDRiD 4-Class) and high-resolution **YOLOv8** (Roboflow Diabetic-Retinopathy-3 1024px).
- **Vibrant Explainability**: Turbo-colormap attention heatmaps blended over the retinal FOV.
- **Multilingual 6-Panel PDF Reports**: Full document exports in **English**, **Hindi (`हिंदी`)**, and **Tamil (`தமிழ்`)** with embedded Devanagari and Tamil typography, plus on-demand spoken counseling.
- **Clinic Workflow Simulation**: Discrete-event stochastic queueing simulator modeling rural patient flows and tele-reviewer capacity.

---

## 🚀 Quick Start Guide

### 1. Prerequisites
- **MATLAB**: R2024a, R2024b, or R2025a
- **Python**: 3.10+ added to system PATH

### 2. Install Python Dependencies
```bash
pip install onnxruntime pillow numpy opencv-python reportlab gTTS
```

### 3. Launch the Application
Open MATLAB, navigate to this directory, and run:
```matlab
launch_retinascan
```
*(Or double-click `launch_app.bat` on Windows).*

---

## 📖 Complete Documentation

For the comprehensive 6-page technical architecture, mathematical formulations, quality gate algorithms, and multi-device setup instructions, refer to:
👉 **[PROJECT_MASTER_DOCUMENTATION.md](PROJECT_MASTER_DOCUMENTATION.md)**

---

## 📂 Repository Structure

```
├── app/                  # Master MATLAB App Designer UI (RetinaScanApp.m)
├── config/               # System and dataset configuration
├── data/
│   ├── cases/            # Persistent local patient registry (ACID MAT-files)
│   ├── models/           # YOLO11n (10.7 MB) and baseline classifiers
│   └── models 2/         # retina_model.onnx (43.7 MB) & yolo_lesions.onnx (45.0 MB)
├── docs/                 # Colab training guide & doctor portal architecture
├── outputs/              # Generated 6-panel PDF reports and audio files
├── simulink/             # Discrete-event queueing model (zero-toolbox)
├── src/                  # Core algorithms: quality, explainability, models, reports
├── launch_app.bat        # Windows desktop launcher
├── launch_retinascan.m   # MATLAB environment initializer
└── PROJECT_MASTER_DOCUMENTATION.md
```

---

## 🏥 Clinical Validation Note
RetinaScan AI is an investigational research decision-support prototype developed for Smart India Hackathon (SIH 2026, Problem Statement 26038). All AI lesion detections and clinical grades require verification by a licensed ophthalmologist before clinical intervention.
