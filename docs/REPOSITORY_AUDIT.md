# RetinaScan MATLAB — Repository Audit Report

**Audited Repository:** `https://github.com/THOUFIKUR/sih2026`  
**Local Inspection Path (Read-Only):** `D:\sih2026\retino`  
**Audited Git Revision:** Commit `df514dc8234973656276f017ba940bc671694367` (2026-09-24 11:35:34 +0530)  
**Audit Scope & Limitations:** Read-only static inspection of all MATLAB scripts, backend models, training pipelines, and dataset directories. No modifications made to `D:\sih2026`.

---

## 1. Reference Repository Architecture & Tree

The reference repository represents a hybrid system comprising:
1. **Frontend (`frontend/`):** React / TypeScript single-page application with ONNX.js/WebWorker client-side inference.
2. **Backend (`backend/`):** Python FastAPI application providing ONNX/PyTorch model serving, YOLOv8 inference, TTS, and reporting.
3. **Data (`data/`):** Local copies of IDRiD and DRIVE datasets, plus sample fundus images.
4. **MATLAB (`matlab/`):** Prototype MATLAB pipeline for image processing, lesion analysis, validation, and Simulink demonstration.

### File Tree Summary
```
D:\sih2026\retino\
├── backend\
│   ├── models\
│   │   ├── best_retinascan_model.pt     (44.56 MB, PyTorch checkpoint)
│   │   ├── retina_model.onnx            (44.77 MB, ONNX FP32)
│   │   ├── yolo_lesions.onnx            (11.75 MB, YOLOv8 ONNX)
│   │   ├── classifier_weights.bin       (30.72 KB)
│   │   └── classifier_weights.npy       (30.85 KB)
│   ├── routes\ (inference.py, report.py, tts.py, abdm_mock.py)
│   ├── scripts\ (export_correct_onnx.py, quantize_models.py, etc.)
│   └── training\ (train_dr_classifier.py, train_yolo_lesions.py)
├── data\
│   ├── drive\ (104 files: train/test splits, images, 1st_manual masks)
│   ├── idrid\ (1,496 files: Segmentation, Disease Grading, Localization)
│   └── samples\ (7 fundus images across Grade 0 to Grade 4)
├── matlab\
│   ├── data_loading\ (load_drive_dataset.m, load_idrid_dataset.m)
│   ├── explainability\ (calibrate_confidence.m, visualize_gradcam_overlay.m)
│   ├── lesion_analysis\ (classify_hemorrhages.m, detect_microaneurysms.m, ...)
│   ├── preprocessing\ (adaptive_clahe_retina.m, check_image_quality.m)
│   ├── reporting\ (export_structured_report.m)
│   ├── retinal_structures\ (detect_optic_disc.m, localize_fovea.m)
│   ├── segmentation\ (segment_retinal_vessels.m)
│   ├── simulink\ (build_simulink_model.m, run_simulation.m, simulink_params.m)
│   ├── validation\ (ablation_study.m, evaluate_lesion_modules.m, ...)
│   ├── benchmark_pipeline.m
│   ├── benchmark_pipeline_to_simulink.m
│   ├── run_retinascan_demo.m
│   └── screen_patient.m
└── scripts\
```

---

## 2. Dataset Inventory & Completeness Check

Inspected directly on the local filesystem:

| Dataset / Directory | Subsets Found | Verified File Count | Completeness Assessment |
|---|---|---|---|
| `data/idrid/A. Segmentation` | Train (54) & Test (27) images; Masks for Microaneurysms, Haemorrhages, Hard Exudates, Soft Exudates, Optic Disc | **473 files** | **COMPLETE:** Matches official IDRiD 81-image segmentation challenge specification. |
| `data/idrid/B. Disease Grading` | Train (413) & Test (103) images; Train/Test Label CSVs | **518 files** | **COMPLETE:** Exactly 516 fundus images + 2 groundtruth CSVs. Official split preserved. |
| `data/idrid/C. Localization` | Train (413) & Test (103) images; OD & Fovea Center coordinate CSVs | **518 files** | **COMPLETE:** Exactly 516 fundus images + 4 groundtruth CSVs. |
| `data/drive` | `training/` (20 images, 20 masks, 20 manual segmentations); `test/` (20 images, 20 masks) | **104 files** | **COMPLETE:** Standard 40-image DRIVE benchmark. |
| `data/samples` | IDRiD Grade 0–4 fundus samples | **7 files** | Complete for unit tests and quickstart verification. |
| **APTOS 2019** | Not found in local directory | **0 files** | **MISSING LOCALLY:** Required for primary 5-class training. |
| **Messidor-2** | Not found in local directory | **0 files** | **MISSING LOCALLY:** Required for external referable-DR validation. |

---

## 3. Model Assets & Compatibility Verification

| Model File | File Size | Binary Check | Architecture & Compatibility Analysis |
|---|---|---|---|
| `best_retinascan_model.pt` | 44,564,086 B | **Real Binary (PyTorch)** | Confirmed `PK` zip archive containing collections `OrderedDict`. Architecture: `timm` EfficientNet-B3 with CBAM attention and Linear(1536, 5) head. Cannot be directly loaded by MATLAB without Python bridge or ONNX conversion. |
| `retina_model.onnx` | 44,772,880 B | **Real Binary (ONNX)** | Confirmed ONNX protobuf. Exported from PyTorch via `export_correct_onnx.py`. Input: `[1, 3, 300, 300]`. Outputs: `logits` [1, 5] and `feature_map` [1, 1536, H, W]. Import into MATLAB blocked by missing Deep Learning Toolbox. |
| `yolo_lesions.onnx` | 11,753,453 B | **Real Binary (ONNX)** | YOLOv8 lesion detector trained on 3 classes (External Bleeding, Exudates/Cotton Wool, Microaneurysms/Hemorrhages). Input: `[1, 3, 1024, 1024]`. Requires Computer Vision Toolbox in MATLAB. |
| `classifier_weights.npy` / `.bin` | ~30 KB | **Real Binary** | Linear layer weights and biases for the 5-class projection head. |

> [!NOTE]
> None of the model files are Git LFS pointers; all are complete, valid binary weights.

---

## 4. Scripts with Side Effects or Mutating Actions

Before executing any script, static inspection revealed:
1. `matlab/benchmark_pipeline_to_simulink.m`:
   - **Mutating Behavior:** Automatically opens `simulink/simulink_params.m` in write mode and replaces parameters using string replacement.
   - **Recommendation:** Do not run in the reference repo. In the new project, isolate parameter configuration into structured data.
2. `matlab/simulink/build_simulink_model.m`:
   - **Mutating Behavior:** Calls `new_system` and `save_system`, creating/overwriting `retinascan_resource_allocation.slx`.
3. `backend/scripts/export_correct_onnx.py`:
   - Writes to `backend/models/retina_model.onnx` if executed.

---

## 5. Critical Gaps Between Reference Code and SIH 26038 Specification

| Specification Requirement | Implementation in Reference Repo | Gap Severity | Action for New Project |
|---|---|---|---|
| **True 5-Class DR Grading in MATLAB** | MATLAB's `screen_patient.m` used heuristic rule thresholds on lesion candidate counts (`maCnt > 5 \|\| exPx > 500`) rather than CNN inference. | **CRITICAL (P0)** | Build genuine deep learning model inference (or ONNX execution engine) producing 5-class logits + referable-DR probability. |
| **Real Grad-CAM Explainability** | `visualize_gradcam_overlay.m` did not compute Grad-CAM from a neural network; it filtered vessel density with `fibermetric` and applied a JET colormap! | **CRITICAL (P0)** | Implement true Grad-CAM using network feature activations and class gradient weighting. |
| **SimEvents Discrete-Event Model** | `build_simulink_model.m` constructed pulse generators + gain blocks; `run_simulation.m` used a discrete for-loop approximation. | **CRITICAL (P0)** | Build a genuine discrete-event resource queue model with entity tracking, queues, and server blocks. |
| **Quality Gate Fail-Closed** | `try/catch` blocks in preprocessing occasionally caught errors silently and returned partial defaults. | **HIGH (P1)** | Enforce strict fail-closed policy: errors or missing data explicitly yield "Ungradable / Recapture". |
| **Temperature Calibration** | `calibrate_confidence.m` defaulted to synthetic data when fewer than 2 inputs were supplied. | **HIGH (P0)** | Calibrate temperature scaling on real held-out validation probabilities, computing genuine ECE and Brier score. |
| **Standalone UI** | Previous UI was React web app; MATLAB side had only basic `screen_patient.m` figure scripts. | **MEDIUM (P2)** | Implement a unified, programmatic `uifigure` app (`RetinaScanApp.m`) following the 6 reference mockups. |
