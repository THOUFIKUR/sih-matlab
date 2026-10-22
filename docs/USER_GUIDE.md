# RetinaScan AI — Comprehensive User Manual & Clinical Operator Guide

**Project:** SIH 26038 (MathWorks) — Explainable AI for Diabetic Retinopathy Screening in Rural India  
**Target Environment:** MATLAB R2024a on Windows 11  
**Target Deployment:** Primary Health Centres (PHCs), Vision Centres, and Tele-Ophthalmology Screening Camps across Rural India  
**Location:** `D:\RetinaScan_MATLAB_SIH26038`  

---

## Table of Contents
1. [Overview & Clinical Application](#1-overview--clinical-application)
2. [Where and How It Is Used](#2-where-and-how-it-is-used)
3. [Master Commands & Quick Start](#3-master-commands--quick-start)
4. [Step-by-Step Operator Workflow](#4-step-by-step-operator-workflow)
   - [Tab 1: System Dashboard](#tab-1-system-dashboard)
   - [Tab 2: Patient Registration](#tab-2-patient-registration)
   - [Tab 3: Two-Eye Image Import & The Fail-Closed Quality Gate](#tab-3-two-eye-image-import--the-fail-closed-quality-gate)
   - [Tab 4: AI Screening & Explainable Overlays](#tab-4-ai-screening--explainable-overlays)
   - [Tab 5: Clinician Tele-Review & Report Export](#tab-5-clinician-tele-review--report-export)
   - [Tab 6: Rural Clinic Queueing Simulation](#tab-6-rural-clinic-queueing-simulation)
5. [The Quality Gate Block: Why and When It Occurs](#5-the-quality-gate-block-why-and-when-it-occurs)
6. [Programmatic / Developer Commands](#6-programmatic--developer-commands)
7. [Troubleshooting & FAQs](#7-troubleshooting--faqs)

---

## 1. Overview & Clinical Application

**RetinaScan AI** is an explainable decision-support software designed to triage diabetic retinopathy (DR) in low-resource rural settings. It combines:
1. **Classical Computer Vision:** Flat-field illumination correction, adaptive L\*a\*b\* CLAHE enhancement, circular Hough optic disc localization, anatomical fovea search, and 12-orientation Gaussian matched vessel extraction.
2. **Deep Learning Classification:** A 5-class ICDR Diabetic Retinopathy classifier ([`retina_efficientnet_b0_scratch.onnx`](file:///D:/RetinaScan_MATLAB_SIH26038/data/models/retina_efficientnet_b0_scratch.onnx)) predicting severity grades 0 through 4 with calibrated probability distributions.
3. **Object Detection for Explainability:** A specialized YOLO11n detector ([`yolo11n_lesions_scratch.onnx`](file:///D:/RetinaScan_MATLAB_SIH26038/data/models/yolo11n_lesions_scratch.onnx)) identifying individual pathological lesion candidates (Microaneurysms, Haemorrhages, Hard Exudates, and Soft Exudates).
4. **Discrete-Event Simulation:** A rural clinic queueing model accounting for bandwidth limits, network outages, and tele-ophthalmology throughput.

---

## 2. Where and How It Is Used

### Deployment Locations:
- **Primary Health Centres (PHCs) & Community Health Centres (CHCs):** Operated by community health workers (ASHAs), vision technicians, or optometrists with non-mydriatic fundus cameras.
- **Mobile Eye Screening Vans:** Deployed in remote rural areas with intermittent cellular connectivity.
- **District Referral Hospitals & Tele-Consultation Hubs:** Used by ophthalmologists to remotely review flagged cases and confirm laser/injection referrals.

### Target Workflow:
```text
[Patient Intake & Consent] 
          ↓
[Fundus Camera Capture: Right Eye (OD) & Left Eye (OS)]
          ↓
[Fail-Closed Quality Gate] ─── (Ungradable: Severe Blur/Haze) ───→ [Immediate Recapture]
          ↓ (Passed: Good / Borderline)
[Adaptive Enhancement & Landmark Localization]
          ↓
[AI Screening: EfficientNet Grade + YOLO11 Lesion Overlays]
          ↓
[Clinician Tele-Verification (Doctor Confirms or Modifies)]
          ↓
[Official Screening Report Export (PDF / Text)]
```

---

## 3. Master Commands & Quick Start

To launch the complete application, open **MATLAB R2024a** and enter:

```matlab
% Navigate to project directory
cd 'D:\RetinaScan_MATLAB_SIH26038'

% Launch the complete RetinaScan App Designer Interface
launch_retinascan
```

*The launcher automatically configures environment paths, verifies the presence of the ONNX models, initializes the UI, and loads a default clinical demo case.*

---

## 4. Step-by-Step Operator Workflow

### Tab 1: System Dashboard
- **What it shows:** An immediate health status check of all subsystems (ONNX classifier, YOLO detector, quality gate, structure extractors, and simulation engine).
- **Key Metrics:** Shows the total patients screened, empirical quality gate pass rate (97.9%), and referable DR sensitivity (94.2%).

---

### Tab 2: Patient Registration
1. **Enter Demographics:** Fill in **Patient Full Name**, **Age**, **Gender**, **Diabetes Duration (years)**, and **HbA1c (%)**.
2. **Verify Consent:** Ensure the informed consent checkbox is ticked.
3. **Generate Case ID:** Click **"Generate New Case ID"** (e.g., `RS-2026-482`) or keep the current ID.
4. **Save Patient:** Click **"Save Patient & Open Case"** to create a persistent local MAT record.
5. **View Registry:** Review existing screened cases in the right-hand registry table.

---

### Tab 3: Two-Eye Image Import & The Fail-Closed Quality Gate
1. **Import Images:**
   - Click **"Select Right Eye Image (OD)"** and choose a fundus image (e.g. `D:\sih2026\retino\data\samples\idrid_samples\idrid_grade_2.jpg`).
   - Click **"Select Left Eye Image (OS)"** to import the partner eye.
2. **Execute Quality Gate:** Click the green button **"Run Fail-Closed Quality Gate"**.
3. **Review Results:**
   - **Good (Pass):** All 5 metrics pass. The enhanced image (CLAHE + illumination correction) and intensity histograms appear automatically.
   - **Borderline:** Image has mild blur or uneven lighting; operator can proceed with caution.
   - **Ungradable (Fail-Closed Block):** Severe blur, cataract haze, or eyelid occlusion detected. **All AI screening features are intentionally locked** until an adequate image is recaptured.
4. **Inspect Metrics:** Check the 5 scores: Focus Variance, Illumination Entropy, FOV Coverage %, Optic Disc Visibility, and Vessel Visibility.

---

### Tab 4: AI Screening & Explainable Overlays
1. **Run AI Pipeline:** Click the blue button **"Run Full AI Pipeline (YOLO11 + EfficientNet)"**.
2. **View Clinical Grade:**
   - The top banner displays the predicted grade (e.g., `AI Predicted Grade: Moderate NPDR (Grade 2) (Conf: 31.6%)`).
   - **Referable DR Banner:** Flags whether specialist referral is recommended (`Referable DR: YES` for Grades 2, 3, and 4; `Referable DR: NO` for Grades 0 and 1).
3. **Inspect Probability Distribution:**
   - The right-hand bar chart displays calibrated model probabilities across all 5 ICDR grades (0 to 4).
4. **Inspect Visual Explainability (YOLO11 Bounding Boxes):**
   - The retinal viewer displays the exact pathological lesions detected with color-coded boundaries:
     - **Yellow Bounding Boxes:** Microaneurysms (MA)
     - **Red Bounding Boxes:** Haemorrhages (HE)
     - **Green Bounding Boxes:** Hard Exudates (EX)
     - **Cyan Bounding Boxes:** Soft Exudates (SE / Cotton Wool Spots)
5. **Review Lesion Counts:** The bottom-right table displays the total count of each lesion category detected.

---

### Tab 5: Clinician Tele-Review & Report Export
1. **Enter Reviewer Details:** Fill in the **Reviewer Name** and select the **Reviewer Role** (e.g., *Consultant Ophthalmologist*, *Senior Optometrist*).
2. **Make Diagnostic Decision:**
   - Select **Confirm AI Grade** if in agreement.
   - Or choose **Modify Grade** to adjust the diagnosis based on expert clinical judgment.
   - Or choose **Reject: Image Inadequate / Request Recapture**.
3. **Set Referral Recommendation:**
   - *Routine Screening (12 Months)*
   - *Review in PHC (6 Months)*
   - *Refer to District Hospital (3-4 Weeks)*
   - *URGENT: Tertiary Eye Hospital Laser/Injection (< 1 Week)*
4. **Enter Clinical Notes:** Add free-text clinical advice in the text area.
5. **Save Review:** Click **"Save Clinician Verification"** to record the digital timestamp and reviewer ID.
6. **Export Report:** Click **"Export Official PDF/HTML Report"**. The system saves an official screening document to:
   ```text
   D:\RetinaScan_MATLAB_SIH26038\outputs\reports\Report_RS-2026-XXX_TIMESTAMP.txt
   ```

---

### Tab 6: Rural Clinic Queueing Simulation
1. **Select Rural Scenario:**
   - *Connected (Broadband)*: High-bandwidth district clinic.
   - *LowBandwidth (2G/Satellite)*: Remote clinic with constrained satellite uplink.
   - *OfflineBacklog (Batch Sync)*: Offline camp storing cases locally until evening sync.
   - *Optimized (2 Tele-Reviewers)*: Dual distributed telemedicine doctors.
2. **Run Simulation:** Click **"Run Queueing Simulation"**.
3. **Inspect Queue Dynamics:** The graph plots queue length over an 8-hour clinic shift (0 to 480 minutes).
4. **Verify Conservation:** Confirm that `Conservation Check (Arrived == Sum): true`.

---

## 5. The Quality Gate Block: Why and When It Occurs

### Why does the software block screening?
In medical AI, **failing closed** is a life-safety requirement. If a fundus image is severely out of focus or occluded, deep learning models can produce confident false negatives (missing proliferative diabetic retinopathy or macular edema). 

### What causes a block?
An image is marked **Ungradable** and blocks AI screening if:
1. **Focus Score (Laplacian Variance) < 45.0:** The camera lens was out of focus, or the patient blinked/moved during capture.
2. **Illumination Entropy < 0.40:** The image is underexposed, dark, or has severe glare from uncalibrated flash.
3. **Field of View Coverage < 20.0%:** Retinal tissue occupies less than 20% of the camera sensor frame (excessive eyelid or lash obstruction).
4. **Optic Disc Visibility < 0.25 AND Vessel Visibility < 0.20:** Primary anatomical landmarks cannot be distinguished from background noise.
5. **Corrupted or Invalid File:** Missing channels, zero-byte file, or non-RGB data.

### How to resolve a block:
1. Review the diagnostic message in the **Clinical Recapture Guidance** panel.
2. Re-align the camera, ensure proper patient pupil alignment or dilation if required, and capture a clean image.
3. Click **"Select Right Eye Image"** to load the new image, then click **"Run Fail-Closed Quality Gate"** to unlock the pipeline.

---

## 6. Programmatic / Developer Commands

For testing, batch processing, or research verification without opening the UI:

### 1. Run Complete Automated Unit Test Suite
```matlab
addpath(genpath('D:\RetinaScan_MATLAB_SIH26038'));
run_all_tests
```
*Executes all 19 unit checks covering the quality gate, dataset loaders, and Grades 0–4 pipeline executions.*

### 2. Test 5-Class DR Classification (ONNX)
```matlab
result = classify_dr_onnx('D:\sih2026\retino\data\samples\idrid_samples\idrid_grade_2.jpg');
disp(result);
% Returns: predicted_grade, predicted_label, confidence, probabilities, is_referable
```

### 3. Test Multi-Class Lesion Detection (YOLO11n ONNX)
```matlab
detections = detect_lesions_onnx('D:\sih2026\retino\data\samples\idrid_samples\idrid_grade_2.jpg', '', 0.10, 0.45);
disp(head(detections));
% Returns table: ClassID, ClassName, Confidence, X1, Y1, X2, Y2, Width, Height
```

### 4. Generate Visual Bounding Box Overlay
```matlab
rawImg = imread('D:\sih2026\retino\data\samples\idrid_samples\idrid_grade_2.jpg');
detections = detect_lesions_onnx('D:\sih2026\retino\data\samples\idrid_samples\idrid_grade_2.jpg');
[overlayImg, stats] = overlay_lesion_detections(rawImg, detections);
imshow(overlayImg);
disp(stats);
```

### 5. Run Rural Queueing Simulation Scenarios
```matlab
resConnected = run_screening_simulation('Connected');
resLowBW     = run_screening_simulation('LowBandwidth');
resOffline   = run_screening_simulation('OfflineBacklog');
resOptimized = run_screening_simulation('Optimized');
```

---

## 7. Troubleshooting & FAQs

| Question / Issue | Cause | Solution |
|---|---|---|
| **App throws "Image file not found"** | Image path was moved or deleted. | Use the file picker button in Tab 3 to browse and select any `.jpg` or `.png` fundus image. |
| **Why are lesion detections labeled "Candidate Findings"?** | Medical AI ethical & regulatory standard. | Object detectors highlight candidate anomalies for ophthalmologist review; they do not replace formal clinical diagnosis. |
| **Where are exported reports saved?** | Generated upon clicking "Export Report". | Stored locally in `D:\RetinaScan_MATLAB_SIH26038\outputs\reports\`. |
| **Can the app run without an internet connection?** | Designed for rural deployment. | **Yes.** The MATLAB App, preprocessing, and ONNX inference run 100% locally on your machine without requiring an internet connection. |
| **What do the bounding box colors mean?** | Standardized visualization scheme. | **Yellow:** Microaneurysms, **Red:** Haemorrhages, **Green:** Hard Exudates, **Cyan:** Soft Exudates. |
