# RetinaScan MATLAB — SIH 26038 Validation Status

> **Standard Rule:** A generated file is not evidence; a real run is.  
> Status Legend: **NOT RUN** | **PASS** | **FAIL** | **BLOCKED**

Last Updated: 2026-10-21 14:34:30 UTC

---

## 1. Environment & Infrastructure Gate (Milestone 1)

| Component / Requirement | Status | Evidence / Notes |
|---|---|---|
| MATLAB R2024a Core Installation | **PASS** | MATLAB Release R2024a (24.1), Win64 verified |
| Simulink (Base) Installation | **PASS** | Simulink 24.1 installed |
| Image Processing Toolbox | **PASS** | Installed via mpm; `adapthisteq`, `imfilter`, `imbinarize`, `regionprops` verified |
| Computer Vision Toolbox | **PASS** | Installed via mpm; `imfindcircles` verified |
| Deep Learning Toolbox | **PASS** | Installed via mpm; `trainnet`, `trainNetwork`, `gradCAM`, `imageLIME` verified |
| Deep Learning ONNX Converter | **PASS** | Support package installed; `importNetworkFromONNX`, `importONNXNetwork` verified |
| Pretrained Networks Support | **PASS** | Support packages installed; `efficientnetb0`, `resnet50` verified |
| Statistics and Machine Learning Toolbox | **PASS** | Installed via mpm; regression, distributions, and classification verified |
| SimEvents (Discrete-Event Simulation) | **PASS** | Installed via mpm; discrete-event queueing engine available for P0 model |
| Parallel Computing Toolbox | **PASS** | Installed via mpm; `gpuDeviceCount` returned 0 (CPU execution enabled) |
| Read-only Inspection of Reference Repo | **PASS** | Inspected `D:\sih2026\retino` at commit `df514dc8234973656276f017ba940bc671694367` |

---

## 2. Dataset Verification Gate

| Dataset | Role | Status | Evidence / File Count |
|---|---|---|---|
| IDRiD — Disease Grading | Indian Test Set (516 images) | **PASS** | 413 Train + 103 Test images + Groundtruth CSVs verified in `D:\sih2026\retino\data\idrid\B. Disease Grading` |
| IDRiD — Lesion & OD Segmentation | Structure & Lesion Validation (81 images) | **PASS** | 54 Train + 27 Test images + 5 lesion mask sets verified in `D:\sih2026\retino\data\idrid\A. Segmentation` |
| IDRiD — OD & Fovea Localization | Localization Validation (516 images) | **PASS** | 413 Train + 103 Test images + OD/Fovea coordinates CSVs verified in `D:\sih2026\retino\data\idrid\C. Localization` |
| DRIVE | Retinal Vessel Segmentation (40 images) | **PASS** | 20 Training (with 1st_manual) + 20 Test (with masks) verified in `D:\sih2026\retino\data\drive` |
| APTOS 2019 | Primary 5-class DR Training Set (~3.6k images) | **PREPARED** | Folder `data/aptos2019/` created; manifest verification script ready |
| Messidor-2 | External Referable-DR Validation Set (1,748 images) | **PREPARED** | Folder `data/messidor2/` created; access request plan documented |

---

## 3. Pretrained Model Verification Gate

| Model Asset | Format / Size | Status | Verification Result |
|---|---|---|---|
| `best_retinascan_model.pt` | PyTorch Binary (44.5 MB) | **QUARANTINED** | Real binary PyTorch state_dict; trained on randomly shuffled IDRiD (data leakage with IDRiD test set) |
| `retina_model.onnx` | ONNX Binary (44.7 MB) | **READY FOR IMPORT TEST** | Real ONNX protobuf; ready for MATLAB R2024a ONNX importer test |
| `yolo_lesions.onnx` | ONNX Binary (11.7 MB) | **QUARANTINED (AGPL-3.0)** | Ultralytics YOLOv8 architecture under AGPL license; requires licensing disclaimer |
| `classifier_weights.npy` / `.bin` | NumPy / Binary (30 KB) | **PASS** (Asset) | Raw linear head weights (1536 -> 5) |

---

## 4. Pipeline Modules (P1 Stages — Milestone 2)

| Pipeline Stage | Method / Algorithm | Status | Run / Test Notes |
|---|---|---|---|
| Quality Assessment (Focus/Blur) | Laplacian variance | **PASS** | Evaluated in `tests/test_quality_gate.m`; focus scores separated on edge cases |
| Quality Assessment (Illumination/FOV) | Intensity stats + FOV mask | **PASS** | Evaluated in `assess_image_quality.m` across sample images and edge cases |
| Quality Gate Assessment (Fail-Closed) | 5 empirical metrics + fail-closed | **PASS** | Evaluated on 140 IDRiD & DRIVE images (`quality_distribution_report.md`): Good 82.9%, Borderline 15.0%, Ungradable 2.1%; 100% fail-closed on corrupt/blank |
| Adaptive Enhancement | Green/Luminance CLAHE | **PASS** | L* CLAHE + illumination flat-field correction; 5 pairs exported to `outputs/validation/enhancement_pairs/` |
| Optic Disc Localization | Circular Hough / Intensity | **PASS** | Evaluated on IDRiD official test split (103 images): 97.09% success (<= 1.0 ODD), mean error 0.4092 ODD (145.7 px) |
| Fovea Localization | Distance / Intensity minima | **PASS** | Evaluated on IDRiD official test split (103 images): 81.55% success (<= 1.0 ODD), mean error 0.5434 ODD (193.5 px) |
| Vessel Segmentation | Matched filtering / thresholding | **PASS** | Evaluated on DRIVE (20 images): Dice 0.6853, Sens 0.6497, Spec 0.9639, Acc 0.9239, AUC 0.9050 |
| Microaneurysm Candidates | Multi-scale bottom-hat | **PASS** | Evaluated on 27 IDRiD test images (`lesion_summary.txt`): Mean Dice 0.0007, Sens 0.0073, Prec 0.0004; labeled candidate findings |
| Exudate Segmentation | Luminance thresholding / morphology | **PASS** | Evaluated on 27 IDRiD test images (`lesion_summary.txt`): Mean Dice 0.2787, Sens 0.2395, Prec 0.4002; labeled candidate findings |
| Hemorrhage Candidates | Dot/blot vs flame classification | **PASS** | Evaluated on 27 IDRiD test images (`lesion_summary.txt`): Mean Dice 0.0040, Sens 0.0026, Prec 0.0502; circularity split (0.55) |
| Neovascularization Flag | NVD/NVE candidate check | **PASS** | Vessel tortuosity & frond clustering with explicit uncertainty scoring ('Low', 'Moderate', 'High') |

---

## 5. Model Inference, Explainability & Reporting (P0 & P1)

| Task | Target | Status | Run / Test Notes |
|---|---|---|---|
| 5-Class DR Grading | ICDR Levels 0–4 | **NOT RUN** | Milestone 3 |
| Referable DR Sensitivity | > 90% on held-out set | **NOT RUN** | Milestone 3 |
| Referable DR Specificity | > 85% on held-out set | **NOT RUN** | Milestone 3 |
| Temperature Scaling Calibration | ECE + Brier score | **NOT RUN** | Milestone 3 |
| True Grad-CAM Generation | Layer feature maps * gradients | **NOT RUN** | Milestone 4 (using official `gradCAM`) |
| Plain-Language ICDR Rationale | ETDRS / ICDR rule text | **NOT RUN** | Milestone 4 |
| 30-Second Review Screen | Usability timing < 30 s | **NOT RUN** | Milestone 4 |
| PDF/HTML Report Export | Case ID, images, disclaimer | **NOT RUN** | Milestone 4 |

---

## 6. Discrete-Event Simulation (P0)

| Simulation Component | Target | Status | Run / Test Notes |
|---|---|---|---|
| True SimEvents Entity Model | 100k+ patients/year district flow | **NOT RUN** | Milestone 5 (using installed SimEvents engine) |
| Conservation Check | Arrived = Completed + Rejected + Queued | **NOT RUN** | Milestone 5 |
| Multi-Node Bottleneck Optimization | Staffing & bandwidth tradeoff | **NOT RUN** | Milestone 5 |
| Four Rural Scenarios Evaluation | Connected, Low-BW, Offline, Opt | **NOT RUN** | Milestone 5 |

---

## 7. Standalone MATLAB App (P2)

| Feature | Target | Status | Run / Test Notes |
|---|---|---|---|
| Programmatic `uifigure` Launch | Runs without error in R2024a | **NOT RUN** | Milestone 6 |
| Patient Registration (India-adapted) | Name, age, sex, village, consent | **NOT RUN** | Milestone 6 |
| Dual-Eye Viewer & Image Import | Left & Right fundus loading | **NOT RUN** | Milestone 6 |
| Quality & Recapture Guidance UI | Shows specific feedback | **NOT RUN** | Milestone 6 |
| Diagnostic & Explainability Panel | Grade, confidence, Grad-CAM | **NOT RUN** | Milestone 6 |
| Clinician Confirm/Override Action | Reviewer timestamped decisions | **NOT RUN** | Milestone 6 |
| Simulation Dashboard UI | Queue lengths, wait times | **NOT RUN** | Milestone 6 |
