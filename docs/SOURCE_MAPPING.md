# RetinaScan MATLAB — Source File Mapping & Migration Strategy

This document details how each module from the reference repository (`D:\sih2026\retino`) is mapped into the new standalone MATLAB project (`D:\RetinaScan_MATLAB_SIH26038`).

## Mandatory Governance Rules

1. **Standard Toolbox Functions Rule:** Once toolboxes are installed, all image processing, computer vision, deep learning, and statistics operations MUST use the official MathWorks toolbox functions (e.g., `adapthisteq`, `imfilter`, `imbinarize`, `regionprops`, `imfindcircles`, `trainnet`, `gradCAM`, `importNetworkFromONNX`). Do not write or maintain custom toolbox-free approximations or fallbacks.
2. **Model Quarantine Rule:** No prediction, confidence score, Grad-CAM map, lesion count, or validation metric from the old repository may be cited or reported as empirical evidence unless it is re-run and verified on a named, held-out dataset split within this project.


| Original File Path | Proposed Action | Target New File Path | Technical Rationale & Adaptations |
|---|---|---|---|
| `matlab/data_loading/load_idrid_dataset.m` | **PORT** | `src/data/load_idrid_dataset.m` | Retain parser logic for IDRiD CSV ground truths and image paths. Harden path handling to support standalone folder structure and add validation tests. |
| `matlab/data_loading/load_drive_dataset.m` | **PORT** | `src/data/load_drive_dataset.m` | Retain DRIVE image/mask pair loader. Ensure compatibility with `imread` without requiring external add-ons. |
| `matlab/preprocessing/check_image_quality.m` | **REWRITE** | `src/preprocessing/assess_image_quality.m` | Refactor into strict fail-closed pipeline: Laplacian variance for focus, intensity entropy/mean for illumination, circular FOV coverage. If error occurs, fail to `Ungradable` with specific recapture guidance. |
| `matlab/preprocessing/adaptive_clahe_retina.m` | **PORT** | `src/preprocessing/enhance_retinal_image.m` | Retain CLAHE on green/luminance channel only. Add check: only label as CLAHE if `adapthisteq` is available; otherwise execute validated contrast stretching and label accurately. |
| `matlab/retinal_structures/detect_optic_disc.m` | **REWRITE** | `src/structures/detect_optic_disc.m` | Replace fragile circle fits with multi-stage candidate localization (high-intensity region filtering, vessel convergence, circular boundary refinement). |
| `matlab/retinal_structures/localize_fovea.m` | **PORT** | `src/structures/localize_fovea.m` | Retain anatomical distance heuristic from optic disc (2.5 disc diameters temporal) combined with macula luminance minimum. |
| `matlab/segmentation/segment_retinal_vessels.m` | **PORT** | `src/segmentation/segment_vessels.m` | Retain 2D matched filtering on inverted green channel. Add Dice and ROC-AUC evaluation against DRIVE ground truths. |
| `matlab/lesion_analysis/detect_microaneurysms.m` | **PORT** | `src/lesions/detect_microaneurysms.m` | Adapt multi-scale Gaussian/morphological top-hat candidate extraction. Validate against IDRiD microaneurysm ground truth masks. |
| `matlab/lesion_analysis/segment_exudates.m` | **PORT** | `src/lesions/segment_exudates.m` | Retain high-luminance exclusion outside optic disc mask. Add morphology cleaning and sub-pixel area measurement. |
| `matlab/lesion_analysis/classify_hemorrhages.m` | **PORT** | `src/lesions/classify_hemorrhages.m` | Separate dot/blot hemorrhages (circularity > threshold) from flame hemorrhages (elongated). |
| `matlab/lesion_analysis/detect_neovascularization.m` | **REWRITE** | `src/lesions/detect_neovascularization.m` | Evaluate vessel tortuosity and fine vessel branching near optic disc (NVD) and retina (NVE). Mark candidates with uncertainty score. |
| `matlab/explainability/visualize_gradcam_overlay.m` | **REWRITE** | `src/explainability/compute_gradcam.m` | **REWRITE ENTIRELY:** The original script created a fake vessel heatmap using `fibermetric`. Replace with genuine Grad-CAM computing gradient-weighted feature map activations from the classification network. |
| `matlab/explainability/calibrate_confidence.m` | **REWRITE** | `src/explainability/calibrate_probabilities.m` | Strip out synthetic fallbacks. Implement Platt/temperature scaling optimization (`fminsearch`) on held-out validation predictions; report ECE and reliability curve. |
| `matlab/reporting/export_structured_report.m` | **REWRITE** | `src/reporting/export_screening_report.m` | Generate comprehensive clinical PDF/HTML reports with Indian patient context, dual-eye findings, calibrated confidence, Grad-CAM overlays, Tamil/Hindi referral advice, and mandatory disclaimer. |
| `matlab/simulink/build_simulink_model.m` | **REWRITE** | `src/simulation/build_simevents_district_model.m` | Replace pulse generators and gain blocks with genuine discrete-event entity queues, servers, and routing blocks representing rural clinic arrivals and telemedicine latency. |
| `matlab/simulink/run_simulation.m` | **REWRITE** | `src/simulation/run_district_simulation.m` | Link directly to measured confusion matrix, rejection rates, and review queues. Implement parameter sweep optimization for staffing/bandwidth to handle 100,000+ patients/year. |
| `matlab/simulink/simulink_params.m` | **PORT** | `src/simulation/simulink_config.m` | Parameterize rural screening model (100k patients/year, 25 clinics, 2G/3G/4G/offline latency, clinician review service times). Remove auto-mutation vulnerability. |
| `matlab/benchmark_pipeline.m` | **PORT** | `scripts/benchmark_execution_times.m` | Measure genuine wallclock `tic`/`toc` runtime per pipeline module on real sample images. |
| `matlab/benchmark_pipeline_to_simulink.m` | **AVOID** | — | **AVOID:** Mutates and overwrites configuration files in-place. Replace with clean programmatic parameter passing. |
| `matlab/run_retinascan_demo.m` | **PORT** | `scripts/run_pipeline_demo.m` | Entry point script running the modular pipeline on a given fundus image. |
| `matlab/screen_patient.m` | **AVOID** | — | **AVOID:** Relied on heuristic lesion count rules instead of trained CNN model inference. |
| `matlab/validation/ablation_study.m` | **REWRITE** | `src/validation/run_ablation_study.m` | Measure 4 distinct configurations on the same split: (a) classical features only, (b) CNN only, (c) CNN + quality gate, (d) CNN + quality gate + lesion evidence. |
| `matlab/validation/evaluate_on_real_data.m` | **PORT** | `src/validation/evaluate_model_performance.m` | Evaluate model on IDRiD test split and compute Quadratic Weighted Kappa, Sensitivity, Specificity with 95% bootstrap CI. |
| `matlab/validation/evaluate_lesion_modules.m` | **PORT** | `src/validation/evaluate_lesions.m` | Compute lesion-level Precision, Recall, and F1 score against IDRiD segmentation ground truth masks. |
| `matlab/validation/evaluate_optic_disc_fovea.m` | **PORT** | `src/validation/evaluate_localization.m` | Compute Euclidean localization error in pixels and mm against IDRiD ground truth coordinates. |
| `backend/models/best_retinascan_model.pt` | **PORT** | `models/best_retinascan_model.pt` | Inspect architecture and convert/export to ONNX or MATLAB network format for offline grading. |
| `backend/models/retina_model.onnx` | **PORT** | `models/retina_model.onnx` | Evaluate compatibility with MATLAB R2024a ONNX importer or integrate via verified ONNX runtime engine. |
| `frontend/*` | **AVOID** | — | Deployed React/Vite web application. Not used in standalone MATLAB app. UI will be built as programmatic `uifigure` (`app/RetinaScanApp.m`). |
