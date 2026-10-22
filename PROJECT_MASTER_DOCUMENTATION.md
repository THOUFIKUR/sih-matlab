# RetinaScan AI — Comprehensive Technical Architecture & Master System Documentation
## SIH Problem Statement 26038: AI-Assisted Tele-Screening for Diabetic Retinopathy in Rural Primary Health Centres (PHCs)

---

## 1. Executive Summary & SIH 26038 Alignment

Diabetic Retinopathy (DR) is the leading cause of preventable blindness among working-age adults worldwide. In rural India, more than 75 million individuals live with diabetes, yet less than 15% undergo annual retinal evaluations due to the acute shortage of trained ophthalmologists at the grassroots Primary Health Centre (PHC) level.

**RetinaScan AI** is an end-to-end, clinically grounded, edge-deployable tele-screening and decision-support platform specifically designed for offline and intermittent-connectivity environments in rural India.

### Key Clinical & Engineering Tenets:
1. **Zero-Toolbox Dependency**: The entire computational core runs on native MATLAB base data structures without requiring commercial proprietary toolboxes (Image Processing, Computer Vision, Deep Learning, or SimEvents toolboxes). Native algorithmic implementations ensure seamless deployment on standard rural clinical hardware.
2. **Fail-Closed Quality Gate**: Ungradable or poor-quality retinal captures (due to cataract opacity, corneal reflections, motion blur, or inadequate illumination) are blocked *before* inference to prevent dangerous false negatives.
3. **Multimodal Clinical Arbitration (Physical Lesion Evidence + Deep Learning)**: Resolves the classical "black-box" failure mode where uncalibrated neural networks predict Grade 0 ("No DR") despite obvious hemorrhages and exudates. The platform grounds the final diagnosis in the International Clinical Diabetic Retinopathy (ICDR) scale using verified microvascular lesion counts.
4. **Bilateral Tele-Screening (`OD + OS`)**: One-click screening evaluates both the Right Eye (`OD`) and Left Eye (`OS`) simultaneously, generating an explainable 6-panel diagnostic matrix.
5. **Full Multilingual Outreach**: Clinical report generation in **English**, **Hindi (`हिंदी`)**, and **Tamil (`தமிழ்`)** with embedded Devanagari and Tamil typography, accompanied by on-demand native audio counseling for illiterate rural patients.
6. **Discrete-Event Queueing Simulation**: Built-in clinic operational simulator modeling rural patient queue dynamics, tele-reviewer utilization, and backlog clearance under constrained bandwidth.

---

## 2. Technology Stack & Software Bill of Materials (SBOM)

| Layer | Component | Version | Role in Architecture |
| :--- | :--- | :--- | :--- |
| **Core UI & Host** | MATLAB App Designer | R2024a / R2024b / R2025a | Native single-window tabbed desktop GUI, state persistence, event dispatching. |
| **Inference Engine** | ONNX Runtime (`onnxruntime`) | 1.16+ | Ultra-fast CPU execution of neural network models on quantized/FP32 graphs. |
| **Primary Classifier** | EfficientNet-B0 (`retina_model.onnx`) | ONNX opset 17 (43.7 MB) | 5-Class DR grading with 1536-channel spatial feature activation maps. |
| **Fallback Classifier** | EfficientNet-B0 (`retina_efficientnet_b0_scratch.onnx`) | ONNX opset 17 (16.0 MB) | Low-footprint fallback 5-class severity classifier. |
| **Primary Detector** | Ultralytics YOLO11n (`yolo11n_lesions_scratch.onnx` / `best.onnx`) | ONNX (10.7 MB) | 4-Class microvascular lesion detector (MA, HE, EX, SE) at 640x640. |
| **Secondary Detector** | Ultralytics YOLOv8 (`yolo_lesions.onnx`) | ONNX v8.4.21 (45.0 MB) | High-resolution (1024x1024) 3-class lesion detector (Bleeding, Exudates, MA/HE). |
| **Report Generation** | Python ReportLab Engine | 3.6+ / 4.0+ | Direct-to-PDF rendering with embedded TrueType/OpenType Indic fonts (`Nirmala.ttc`). |
| **Speech Counseling** | Google Text-to-Speech (`gTTS`) | 2.5+ | Cloud-synthesized and locally cached patient voice advice in Hindi, Tamil, and English. |
| **Image Processing** | Base MATLAB + Python OpenCV / Pillow | Native / cv2 4.8+ | Convolutional Shannon entropy, gradient magnitude, turbo colormap blending. |
| **Data Persistence** | Native MATLAB MAT-Files (`.mat`) | Level 7.3 MAT | Robust ACID local patient database (`patient_registry.mat` and `case_*.mat`). |

---

## 3. Comprehensive Page-by-Page Technical Breakdown

```
+----------------------------------------------------------------------------------------------------+
|                                    RETINASCAN AI ARCHITECTURE                                      |
+----------------------------------------------------------------------------------------------------+
| [Tab 1: System Overview]  --> Hardware Health, ONNX Model Validation, Environment Setup           |
| [Tab 2: Patient Intake]   --> Demographics, Diabetes Duration, HbA1c, Informed Consent Gate       |
| [Tab 3: Quality Gate]     --> Retinal FOV Masking, Focus SNR, Shannon Entropy, CLAHE Contrast      |
| [Tab 4: AI Screening]     --> EfficientNet-B0 + YOLO11n/YOLOv8 + Turbo Heatmaps + ICDR Arbitration |
| [Tab 5: Review & Report]  --> Clinician Sign-off, 6-Panel Bordered PDF (EN/HI/TA), Audio TTS       |
| [Tab 6: Clinic Simulation]--> Discrete-Event Stochastic Queueing Model (M/M/1 & M/M/c Dynamics)   |
+----------------------------------------------------------------------------------------------------+
```

---

### Tab 1: System Overview & Deployment Dashboard

#### Clinical & Operational Purpose
Provides rural operators (Auxiliary Nurse Midwives / ASHA workers) with immediate situational awareness of system health, active deep learning models, local database counts, and network status before patient intake commences.

#### Functional Mechanics:
- **Environment Autoconfiguration**: Recursively adds all project paths (`app`, `src`, `config`, `data`, `scripts`, `simulink`) to the MATLAB runtime environment.
- **Model Graph Verification**: Probes `data/models` and `data/models 2` to verify model integrity:
  - Validates `retina_model.onnx` (43.7 MB EfficientNet-B0)
  - Validates `yolo11n_lesions_scratch.onnx` (10.7 MB YOLO11n)
  - Validates `yolo_lesions.onnx` (45.0 MB YOLOv8)
- **Database Metrics**: Reads `patient_registry.mat` and counts total screened cases, referable flags, and pending clinician reviews.

---

### Tab 2: Patient Intake & Demographics Registry

#### Clinical & Operational Purpose
Enforces clinical traceability, epidemiological data collection, and legally binding informed consent before capturing or analyzing retinal photographs.

#### Schema Fields:
- `CaseID`: Unique ISO-like identifier formatted as `RS-YYYYMMDD-XXXX` (e.g., `RS-20261022-0001`).
- `PatientName`, `Age`, `Gender`, `Contact`, `InsuranceID` (Ayushman Bharat / PM-JAY / State Health Card).
- `DiabetesDuration`: Years since diagnosis (crucial risk modifier for microvascular proliferation).
- `HbA1c`: Glycated hemoglobin percentage (marker for glycemic control).
- `ConsentCheckbox`: Mandatory boolean gate. **If consent is unchecked, all subsequent tabs remain disabled.**

#### Persistence Implementation:
Data is committed to `data/cases/patient_registry.mat` via native MATLAB atomic write protocols, ensuring that power loss or system crashes at rural clinics cannot corrupt existing records.

---

### Tab 3: Retinal Image Import & Fail-Closed Quality Gate

#### Clinical & Operational Purpose
Implements a strict **fail-closed quality verification gate**. Poor quality images are identified immediately, and clear recapture advice (e.g., *"Patient blinked — recapture"*, *"Corneal glare detected — re-angle fundus camera"*) is presented to the operator.

#### Mathematical Formulations & Quality Metrics:

1. **Retinal Field-of-View (FOV) Adaptive Segmentation**:
   $$\text{FOV}_{\text{mask}}(x, y) = \begin{cases} 1 & \text{if } I_{\text{gray}}(x, y) > \tau_{\text{bg}} \\ 0 & \text{otherwise} \end{cases}$$
   where $\tau_{\text{bg}}$ is dynamically estimated from background pixels ($\approx 18-20$ intensity).

2. **Illumination Uniformity & Shannon Entropy**:
   $$H = -\sum_{i=0}^{255} p(i) \log_2 p(i)$$
   where $p(i)$ is the normalized empirical histogram of green-channel intensities inside the FOV.
   - **Quality Criterion**: $H \ge 3.500$ bits (Rejects severely underexposed or overexposed captures).

3. **High-Frequency Vascular Sharpness (Sobel Gradient Energy)**:
   $$G_x = I * K_x, \quad G_y = I * K_y, \quad G_{\text{mag}} = \sqrt{G_x^2 + G_y^2}$$
   $$\text{Sharpness Score} = \frac{1}{|\text{FOV}|} \sum_{(x,y) \in \text{FOV}} G_{\text{mag}}(x, y)$$
   - **Quality Criterion**: $\text{Score} \ge 1.500$ (Rejects optical blur, motion artifacts, or severe cataracts).

4. **Signal-to-Noise Ratio (SNR) Estimation**:
   $$\text{SNR}_{\text{dB}} = 10 \log_{10}\left(\frac{\mu_{\text{retina}}}{\sigma_{\text{background}} + \epsilon}\right)$$
   - **Quality Criterion**: $\text{SNR} \ge 12.0\text{ dB}$.

5. **Optic Disc Visibility Contrast**:
   Computes local intensity variance in the top 2% brightest non-glare circular zones inside the nasal quadrant to guarantee that the primary anatomical landmark is distinguishable.

6. **Contrast-Limited Adaptive Histogram Equalization (CLAHE)**:
   Enhances fine retinal capillaries and microaneurysms by operating in the Lab luminance channel with exponential Rayleigh distribution mapping:
   $$\text{Rayleigh CDF: } y = y_{\text{min}} + \sqrt{-2\alpha^2 \ln(1 - x)}$$

---

### Tab 4: AI Screening, Lesion Detection & Explainability

#### Clinical & Operational Purpose
The centerpiece diagnostic module providing explainable multi-model inference, bounding box visual localization, thermal attention heatmaps, and lesion-grounded clinical staging.

#### 1. Dual-Model Architecture:
- **Primary Lesion Detector**: Ultralytics **YOLO11n** (Trained on IDRiD; 4 microvascular classes: Microaneurysms, Haemorrhages, Hard Exudates, Soft Exudates).
- **Supplementary Detector**: Ultralytics **YOLOv8** (Trained on Roboflow Diabetic-Retinopathy-3 at 1024x1024 resolution; 3 classes: External Bleeding, Exudates/CottonWool/Scars, Microaneurysms/Hemorrhages).
- **Classification Engine**: **EfficientNet-B0** (`retina_model.onnx`, 43.7 MB; 5-class ICDR stage output).

#### 2. Model-Aware Caching ("If it's already there, leave that"):
The pipeline tags every detection output with its `ModelSource` (`YOLO11n (IDRiD)` vs `YOLOv8 (Roboflow)`). When clicking **`Run Both Eyes (OD+OS)`**:
- If OD or OS has already been computed with the currently active model, re-inference is skipped, dramatically speeding up clinical throughput.
- If the operator switches models in the dropdown, the cache invalidates automatically and re-executes inference with the newly selected architecture.

#### 3. Clinical Grad-CAM Attention Heatmap (Vibrant Turbo Mapping):
Generates a thermal activation gradient highlighting microvascular lesions and texture irregularities:
- **Gradient Energy**: Extracted from hemoglobin absorption in the green channel ($\lambda \approx 540-575\text{ nm}$).
- **Lesion Density Kernel Superposition**:
  $$D_{\text{lesion}}(x, y) = \sum_{i=1}^{N} c_i \cdot \exp\left(-\frac{(x - x_i)^2 + (y - y_i)^2}{2\sigma_{\text{lesion}}^2}\right)$$
- **Turbo Polynomial Colormap Mapping**:
  Smooth piecewise polynomial approximation generating deep indigo $\rightarrow$ turquoise $\rightarrow$ amber $\rightarrow$ radiant red thermal gradients over the retinal FOV.
- **Alpha Blending**:
  $$I_{\text{blend}}(x, y) = (1 - \alpha) \cdot I_{\text{fundus}}(x, y) + \alpha \cdot I_{\text{turbo}}(x, y)$$

#### 4. Clinically Grounded DR Grading Arbitration (ICDR Rules):
Resolves flat or uncalibrated neural network logits by correlating ground-truth physical lesion detections with the International Clinical Diabetic Retinopathy (ICDR) scale:

$$\text{Final Stage} = \begin{cases} 
\text{Grade 4 (Proliferative DR)} & \text{if } N_{\text{bleed}} \ge 1 \text{ or } N_{\text{total}} \ge 30 \text{ or } N_{\text{HE}} \ge 20 \text{ or } (N_{\text{HE}} \ge 12 \land N_{\text{SE}} \ge 4) \\
\text{Grade 3 (Severe NPDR)}      & \text{if } N_{\text{total}} \ge 15 \text{ or } N_{\text{HE}} \ge 10 \text{ or } (N_{\text{HE}} \ge 6 \land N_{\text{SE}} \ge 2) \\
\text{Grade 2 (Moderate NPDR)}    & \text{if } N_{\text{total}} \ge 4 \text{ or } N_{\text{EX}} \ge 2 \text{ or } N_{\text{HE}} \ge 2 \text{ or } N_{\text{SE}} \ge 1 \\
\text{Grade 1 (Mild NPDR)}        & \text{if } 1 \le N_{\text{total}} \le 3 \text{ (Microaneurysms or solitary exudate)} \\
\text{Grade 0 (No DR)}            & \text{if } N_{\text{total}} = 0 \text{ (Zero microvascular lesions)}
\end{cases}$$

- **Single-Lesion Safety Rule**: If only 1 lesion is detected (e.g., 1 isolated hard exudate), the system is strictly bounded to **Grade 1: Mild NPDR (82.0% confidence, Referable: NO)**, preventing over-referral to tertiary eye hospitals.
- **Referable DR Threshold**: Defined as $\text{Grade} \ge 2$ (Moderate NPDR, Severe NPDR, or Proliferative DR), triggering referral alerts in bold red.

---

### Tab 5: Clinician Review & Multilingual Reporting

#### Clinical & Operational Purpose
Facilitates tele-ophthalmologist asynchronous review, hospital facility assignment, priority timeframe scheduling, export of a standardized 6-panel PDF report, and multilingual speech counseling.

#### 1. Standardized 6-Panel Retinal Comparison Matrix:
| Panel | Left Column (Right Eye - OD) | Right Column (Left Eye - OS) |
| :--- | :--- | :--- |
| **Row 1** | Panel 1: Original Fundus Photograph (OD) | Panel 2: Original Fundus Photograph (OS) |
| **Row 2** | Panel 3: YOLO Microvascular Lesion Badges (OD) | Panel 4: YOLO Microvascular Lesion Badges (OS) |
| **Row 3** | Panel 5: CLAHE Contrast Enhanced Image (OD) | Panel 6: Thermal Grad-CAM Attention Heatmap (OS) |

#### 2. Multilingual PDF Generation Engine (`generate_clinical_pdf.py`):
- **Borders & Branding**: Double navy outer border ($1.5\text{ pt}$) with subtle inner gold accent line ($0.5\text{ pt}$), Government of India SIH header, and cryptographic QR code.
- **Typography Engine**: Uses Windows system font `C:/Windows/Fonts/Nirmala.ttc` (subfontIndex=0) for TrueType font rendering of Devanagari (Hindi) and Tamil Unicode glyphs without square box artifacts (`tofu`).
- **Pathophysiological Patient Education**: Explains *why* retinal vessels leak due to pericyte loss and provides concrete clinical targets ($\text{HbA1c} < 7.0\%$, $\text{Blood Pressure} < 130/80\text{ mmHg}$).

#### 3. On-Demand Multilingual Audio Counseling:
- Audio is **not** downloaded during report sign-off.
- Clicking **`English`**, **`Hindi (हिंदी)`**, or **`Tamil (தமிழ்)`** triggers on-demand gTTS speech synthesis:
  - Generates clear, non-jargon spoken counseling explaining the eye grade and follow-up timeline in the patient's native dialect.
  - Automatically invokes the system audio player (`winopen`) for playback at the primary clinic.

---

### Tab 6: Clinic Workflow Simulation (Queueing Dynamics)

#### Clinical & Operational Purpose
A discrete-event stochastic capacity planning tool enabling health administrators to model clinic shift operations, evaluate screening bottlenecks, and plan tele-ophthalmology network capacity across rural districts.

#### Mathematical Queueing Model:
- **Arrival Process**: Non-homogeneous Poisson process with mean arrival rate $\lambda$ (patients/hour).
- **Service Process**: Exponentially distributed service durations ($T_{\text{service}} \sim \text{Exp}(\mu)$):
  - Retinal imaging intake time: $\mu_{\text{capture}} \approx 4-6\text{ mins}$.
  - Quality verification: $\mu_{\text{quality}} \approx 0.5\text{ mins}$.
  - AI automated inference: $\mu_{\text{AI}} \approx 0.2\text{ mins}$.
  - Remote clinician tele-review: $\mu_{\text{review}} \approx 3-8\text{ mins}$ (dependent on connectivity scenario).
- **Scenarios Modeled**:
  1. `Connected`: Fiber/4G continuous synchronization.
  2. `LowBandwidth`: Compressed image batch transmission with delayed remote sign-off.
  3. `OfflineBacklog`: Local edge triage; asynchronous night batch synchronization.
  4. `Optimized`: Parallel dual-eye capture with automated fail-closed recapture alerts.
- **Conservation Check**:
  $$\text{Total Arrived} \equiv \text{Completed Screenings} + \text{Quality Rejections} + \text{Queued at Shift End}$$

---

## 4. Setup Guide for Running on Another Laptop

Follow this step-by-step checklist to deploy RetinaScan AI on a new laptop or clinical workstation.

### Prerequisites & System Requirements
- **Operating System**: Windows 10 or Windows 11 (64-bit).
- **MATLAB Version**: MATLAB R2024a, R2024b, or R2025a (Standard desktop install).
- **Python**: Python 3.10, 3.11, or 3.12 (Added to Windows PATH).
- **RAM**: Minimum 8 GB (16 GB recommended).
- **Storage**: Minimum 2 GB free disk space for models and runtime assets.

---

### Step 1: Clone or Copy the Repository
Clone the repository using Git:
```bash
git clone https://github.com/THOUFIKUR/sih-matlab.git "C:\RetinaScan_AI"
cd "C:\RetinaScan_AI"
```
*(Alternatively, copy the `RetinaScan_MATLAB_SIH26038` folder to the target laptop's drive).*

---

### Step 2: Configure Python Virtual Environment & Dependencies
Open Command Prompt (`cmd.exe`) or PowerShell on the target laptop and execute:
```bash
# Verify Python is available
python --version

# Install required inference, computer vision, and reporting packages
pip install onnxruntime pillow numpy opencv-python reportlab gTTS
```

---

### Step 3: Verify Indic Fonts (For Hindi & Tamil Reports)
The PDF generator utilizes `Nirmala UI`, which is pre-installed on all modern Windows 10/11 installations:
- Confirm that `C:\Windows\Fonts\Nirmala.ttc` exists on the target machine.
- If running on Windows Server or a custom Windows Lite edition, install the "Optional Hindi and Tamil Supplemental Fonts" via:
  `Settings > Time & Language > Language > Add a Language > Hindi / Tamil`.

---

### Step 4: Launch RetinaScan AI in MATLAB
1. Launch MATLAB on the target machine.
2. In the MATLAB Current Folder toolbar, navigate to the project directory:
   ```matlab
   cd('C:\RetinaScan_AI')
   ```
3. Run the automated startup configuration script:
   ```matlab
   launch_retinascan
   ```
4. The system will verify all 3 neural network models, configure runtime paths, and launch the App Designer GUI.

---

### Step 5: Test the Complete Screening Workflow
1. **Tab 2 (Patient Intake)**: Enter patient details (e.g., *"Ramesh Kumar"*, Age: `56`, Diabetes: `8` years, HbA1c: `8.4%`), check **"Informed Consent Obtained"**, and click **Save Patient Registration**.
2. **Tab 3 (Quality Gate)**: Click **Choose Image (OD)** and select `data/aptos2019/test_images/0005cfc8afb6.png`. Click **Run Quality Assessment**. Notice the animated loading dialog; the image will pass with green metrics.
3. **Tab 4 (AI Screening)**: Click **Run Both Eyes (OD+OS)**. Watch the animated progress dialog analyze both eyes. Inspect the detected microvascular lesions, Turbo attention heatmap, and calibrated DR grade.
4. **Tab 5 (Review & Report)**: Enter reviewing clinician details, select **Language: Tamil (`தமிழ்`)** or **Hindi (`हिंदी`)**, and click **Generate 6-Panel PDF**. Open the resulting professional PDF in `outputs/reports/`. Click the **Tamil** audio button to listen to native voice counseling.
5. **Tab 6 (Simulation)**: Click **Run Queueing Simulation** to observe patient queue dynamics across an 8-hour shift.

---

## 5. Architectural Directory Layout

```
D:\RetinaScan_MATLAB_SIH26038\
├── app\
│   └── RetinaScanApp.m             # Master MATLAB App Designer UI (All 6 Tabs)
├── config\
│   └── dataset_config.m            # Clinical thresholds & camera configuration
├── data\
│   ├── cases\                      # Local ACID patient registry database
│   │   └── patient_registry.mat    # Persistent table of all screened cases
│   ├── models\                     # Standard models
│   │   ├── best.onnx               # Primary YOLO11n lesion detector (10.7 MB)
│   │   ├── retina_efficientnet_b0_scratch.onnx
│   │   └── yolo11n_lesions_scratch.onnx
│   └── models 2\                   # Advanced models
│       ├── retina_model.onnx       # Primary 43.7 MB EfficientNet-B0 Classifier
│       └── yolo_lesions.onnx       # Supplementary 45.0 MB YOLOv8 1024px Detector
├── docs\                           # Documentation & architecture guides
│   ├── DOCTOR_PORTAL_ARCHITECTURE.md
│   └── GOOGLE_COLAB_TRAINING_GUIDE.md
├── outputs\
│   ├── figures\                    # Simulation curves & diagnostic plots
│   └── reports\                    # Generated clinical PDF & MP3 audio reports
├── scripts\                        # Training & verification helper scripts
├── simulink\
│   └── run_screening_simulation.m  # Discrete-event stochastic queueing simulator
├── src\
│   ├── classification\             # Native image processing & CLAHE
│   ├── explainability\             # Turbo Grad-CAM heatmap & labeled overlays
│   │   ├── generate_retinal_heatmap.m
│   │   ├── overlay_lesion_detections.m
│   │   └── render_labeled_boxes.py
│   ├── models\                     # ONNX Inference bridges & ICDR arbitration
│   │   ├── arbitrate_dr_grade_from_lesions.m
│   │   ├── classify_dr_onnx.m
│   │   ├── detect_lesions_onnx.m
│   │   └── run_onnx_inference.py
│   ├── quality\                    # Fail-closed quality assessment algorithms
│   │   └── assess_image_quality.m
│   └── reports\                    # Multilingual PDF & gTTS audio engines
│       ├── export_clinical_report_full.m
│       ├── generate_clinical_pdf.py
│       └── generate_multilingual_audio.py
├── launch_app.bat                  # One-click Windows desktop launcher
├── launch_retinascan.m             # MATLAB master environment initializer
└── PROJECT_MASTER_DOCUMENTATION.md # This master document
```

---

## 6. Summary of Key Achievements for SIH 26038

1. **Robust Clinical Safety**: Solved the scratch classifier "No DR Grade 0" defect by coupling physical lesion evidence with ICDR criteria.
2. **Eliminated Over-referral**: Solved single-lesion false alarms; a solitary hard exudate correctly yields **Mild NPDR (Grade 1)** rather than Grade 4.
3. **Inclusive Healthcare**: Native Hindi and Tamil PDF reports with clear Devanagari and Tamil Unicode typography alongside on-demand spoken counseling.
4. **Offline Resilience**: Runs completely on rural clinic hardware with local MAT-file database persistence and zero proprietary toolbox requirements.
