# RetinaScan MATLAB — Dataset Manifest & Inventory

**Verification Date:** 2026-10-21  
**Project:** SIH 26038 — Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## 1. Local Dataset Inventory Summary

| Dataset Name | Primary Purpose / Role | Local Path | Verified Files | Status |
|---|---|---|---|---|
| **IDRiD — Disease Grading** | External Indian Test Set (5-Class & Referable DR) | `D:\sih2026\retino\data\idrid\B. Disease Grading` | 516 Images + 2 CSVs | **VERIFIED & READY** |
| **IDRiD — Segmentation** | Lesion & Optic Disc Segmentation Validation | `D:\sih2026\retino\data\idrid\A. Segmentation` | 81 Images + 390 Masks | **VERIFIED & READY** |
| **IDRiD — Localization** | Optic Disc & Fovea Center Coordinate Validation | `D:\sih2026\retino\data\idrid\C. Localization` | 516 Images + 4 CSVs | **VERIFIED & READY** |
| **DRIVE** | Vessel Segmentation Validation (Dice/AUC) | `D:\sih2026\retino\data\drive` | 40 Images + 60 Masks | **VERIFIED & READY** |
| **IDRiD Samples** | Quickstart & Unit Testing Suite | `D:\sih2026\retino\data\samples\idrid_samples` | 5 Images (Grades 0–4) | **VERIFIED & READY** |
| **APTOS 2019** | Primary 5-Class CNN Model Training | — | 0 Images | **MISSING LOCALLY** |
| **Messidor-2** | External Patient-Level Referable DR Validation | — | 0 Images | **MISSING LOCALLY** |

---

## 2. Detailed Dataset Specifications

### 2.1 IDRiD (Indian Diabetic Retinopathy Image Dataset)
- **Origin & Clinical Context:** Acquired from an eye clinic in Nanded, Maharashtra, India using a Kowa VX-10 alpha digital fundus camera with a 50° field of view. All subjects are Indian patients, making it the most clinically relevant benchmark for SIH 26038.
- **Licence:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **Citation:** Porwal, P. et al., "Indian Diabetic Retinopathy Image Dataset (IDRiD): A Database for Diabetic Retinopathy Screening Research," *Data*, 2018.

#### Subsets & Splits:
1. **Part B: Disease Grading (`data/idrid/B. Disease Grading`)**
   - **Original Images:** 516 color fundus images (`.jpg`, 4288 × 2848 resolution)
   - **Training Split:** 413 images (`IDRiD_001.jpg` to `IDRiD_413.jpg`)
   - **Testing Split:** 103 images (`IDRiD_414.jpg` to `IDRiD_516.jpg`)
   - **Labels:** Ground truth CSVs providing 5-class ICDR Retinopathy grade (0 to 4) and Diabetic Macular Edema (DME) risk grade (0 to 2).
   - **Strict Split Rule:** Testing split is strictly held out for external Indian evaluation; **never train on the test split.**

2. **Part A: Segmentation (`data/idrid/A. Segmentation`)**
   - **Original Images:** 81 images (54 training, 27 testing)
   - **Pixel Ground Truth Masks (`.tif` binary masks):**
     - Microaneurysms: 54 train masks, 27 test masks
     - Haemorrhages: 53 train masks, 27 test masks
     - Hard Exudates: 54 train masks, 27 test masks
     - Soft Exudates: 26 train masks, 14 test masks
     - Optic Disc: 54 train masks, 27 test masks

3. **Part C: Localization (`data/idrid/C. Localization`)**
   - **Original Images:** 516 images (413 training, 103 testing)
   - **Ground Truths:** CSV files specifying exact (X, Y) pixel coordinates of the Optic Disc Center and Fovea Center.

---

### 2.2 DRIVE (Digital Retinal Images for Vessel Extraction)
- **Origin:** University Medical Center Utrecht, Netherlands. 45° FOV images acquired with a Canon CR5 non-mydriatic 3CCD camera.
- **Licence:** Open access for non-commercial research.
- **Citation:** Staal, J. et al., "Ridge based vessel segmentation in color images of the retina," *IEEE TMI*, 2004.
- **Role:** Strict vessel segmentation benchmarking (Dice coefficient, Sensitivity, Specificity, AUC). **Not used for DR grading.**
- **Structure:**
  - `training/`: 20 images (`.tif`), 20 FOV masks (`.gif`), 20 expert manual vessel segmentations (`1st_manual/*.tif`).
  - `test/`: 20 images (`.tif`), 20 FOV masks (`.gif`), 20 expert manual segmentations (`1st_manual/*.tif`).

---

### 2.3 APTOS 2019 Blindness Detection (Missing Locally)
- **Role:** Primary dataset for training deep learning 5-class DR classification models.
- **Specification:** 3,662 labeled high-resolution retina photographs from Aravind Eye Hospital, India.
- **Data Integrity Rule:** Contains duplicate and near-duplicate images across clinic visits. Must be de-duplicated via Perceptual Hash (pHash) prior to splitting.
- **Current Status:** Not present in `D:\sih2026`.
- **Acquisition Path:** Available via Kaggle Competition API (`kaggle competitions download -c aptos2019-blindness-detection`). Size: ~9.5 GB. Requires user approval before downloading.

---

### 2.4 Messidor-2 (Missing Locally)
- **Role:** External validation of referable diabetic retinopathy (Level 2+) sensitivity and specificity.
- **Specification:** 1,748 fundus photographs (874 patients, 2 eyes per patient) with published adjudicated consensus reference labels (Krause et al., *Ophthalmology*, 2018).
- **Split Rule:** Must be split strictly by patient ID so images from the same patient never appear in both calibration and evaluation sets.
- **Current Status:** Not present in `D:\sih2026`.
- **Acquisition Path:** Available upon request from ADCIS / Messidor consortium. Size: ~2.5 GB. Requires user approval before downloading.
