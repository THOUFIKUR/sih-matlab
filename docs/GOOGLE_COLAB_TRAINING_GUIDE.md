# Google Colab Model Training Guide — RetinaScan AI (SIH 26038)

**Project:** SIH 26038 — Explainable AI for Diabetic Retinopathy Screening in Rural India  
**Target Environment:** Google Colab with Free NVIDIA T4 GPU  
**Local MATLAB Project:** `D:\RetinaScan_MATLAB_SIH26038`  
**Reference Repo (Read-Only):** `D:\sih2026`  

---

## Table of Contents
1. [Overview & Strict Training Policies](#1-overview--strict-training-policies)
2. [Step 1: Open Google Colab & Select GPU Runtime](#step-1-open-google-colab--select-gpu-runtime)
3. [Step 2: Verify GPU Allocation](#step-2-verify-gpu-allocation)
4. [Step 3: Connect Google Drive Safely](#step-3-connect-google-drive-safely)
5. [Step 4: Prepare and Upload Datasets to Google Drive](#step-4-prepare-and-upload-datasets-to-google-drive)
6. [Step 5: Expected Dataset Folder Layout](#step-5-expected-dataset-folder-layout)
7. [Step 6: Opening and Running the Notebooks](#step-6-opening-and-running-the-notebooks)
8. [Step 7: Executing Smoke Test & Pilot Run First](#step-7-executing-smoke-test--pilot-run-first)
9. [Step 8: Full Training & Resuming from Checkpoints](#step-8-full-training--resuming-from-checkpoints)
10. [Step 9: Troubleshooting Disconnections, OOM & Errors](#step-9-troubleshooting-disconnections-oom--errors)
11. [Step 10: Where Outputs & Checkpoints are Saved](#step-10-where-outputs--checkpoints-are-saved)
12. [Step 11: Downloading Exported Models to Windows](#step-11-downloading-exported-models-to-windows)
13. [Step 12: Installing Models in Local MATLAB Project](#step-12-installing-models-in-local-matlab-project)
14. [Step 13: Verifying Inference in MATLAB R2024a](#step-13-verifying-inference-in-matlab-r2024a)
15. [Step 14: How to Safely Stop and Resume Later](#step-14-how-to-safely-stop-and-resume-later)

---

## 1. Overview & Strict Training Policies

To ensure complete scientific integrity and compliance with the Master Specification:
- **Zero Pretrained Weights:** All models are trained **from scratch** with random weight initialization (`weights=None`). No ImageNet weights and no weights from old repositories are used.
- **Untouched Held-Out Test Splits:** Model development and hyperparameter tuning occur strictly on the official IDRiD training splits (using stratified 80/20 train/validation splits). The official testing splits (103 grading images, 27 segmentation images) remain untouched until final evaluation.
- **No Secrets in Code:** No Kaggle API keys, tokens, or personal credentials are hardcoded into notebooks or documentation.

---

## Step 1: Open Google Colab & Select GPU Runtime

1. Open your web browser and navigate to [Google Colab](https://colab.research.google.com/).
2. Click **File → Upload notebook**.
3. Select either:
   - `D:\RetinaScan_MATLAB_SIH26038\notebooks\train_efficientnet_b0_from_scratch.ipynb` (for 5-class DR classifier), or
   - `D:\RetinaScan_MATLAB_SIH26038\notebooks\train_yolo26n_lesions_from_scratch.ipynb` (for lesion detector).
4. In the top menu bar, click **Runtime → Change runtime type**.
5. Under **Hardware accelerator**, select **T4 GPU** (or any available GPU).
6. Click **Save**.

---

## Step 2: Verify GPU Allocation

In the very first code cell, execute:
```python
import torch
print("CUDA Available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("Assigned GPU:", torch.cuda.get_device_name(0))
    print(f"Total VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
```
- **Expected Output:**
  - `CUDA Available: True`
  - `Assigned GPU: Tesla T4` (or similar)
  - `Total VRAM: ~15.84 GB`
- If it returns `False`, verify your runtime settings in **Runtime → Change runtime type**.

---

## Step 3: Connect Google Drive Safely

Run the Drive mounting cell:
```python
from google.colab import drive
drive.mount('/content/drive')
```
- A Google popup will ask for permission to access your Google Drive. Click **Connect to Google Drive**.
- Google Drive will be mounted at `/content/drive/MyDrive/`. This allows checkpoints, logs, and ONNX models to be persisted even if the Colab session disconnects.

---

## Step 4: Prepare and Upload Datasets to Google Drive

> [!IMPORTANT]
> **READ-ONLY PROTECTION:** Never edit or move files inside `D:\sih2026`. Create a zip copy on your Windows machine to upload to Google Drive.

### A. For Notebook A (IDRiD Disease Grading):
1. In Windows PowerShell, create a zip archive of the grading dataset:
   ```powershell
   Compress-Archive -Path "D:\sih2026\retino\data\idrid\B. Disease Grading" -DestinationPath "D:\idrid_grading.zip"
   ```
2. Upload `D:\idrid_grading.zip` to your Google Drive under a folder named `RetinaScan_Data/`.
3. In Colab, unzip it directly to the local Colab disk for high-speed SSD access:
   ```bash
   !unzip -q "/content/drive/MyDrive/RetinaScan_Data/idrid_grading.zip" -d "/content/idrid/"
   ```

### B. For Notebook B (IDRiD Lesion Segmentation):
1. In Windows PowerShell, create a zip archive of the segmentation dataset:
   ```powershell
   Compress-Archive -Path "D:\sih2026\retino\data\idrid\A. Segmentation" -DestinationPath "D:\idrid_segmentation.zip"
   ```
2. Upload `D:\idrid_segmentation.zip` to your Google Drive under `RetinaScan_Data/`.
3. In Colab, unzip it:
   ```bash
   !unzip -q "/content/drive/MyDrive/RetinaScan_Data/idrid_segmentation.zip" -d "/content/idrid/"
   ```

---

## Step 5: Expected Dataset Folder Layout

The notebooks expect the following unzipped folder layout on the Colab filesystem (`/content/idrid/`):

```text
/content/idrid/
├── A. Segmentation/
│   ├── 1. Original Images/
│   │   ├── a. Training Set/       (54 images: IDRiD_01.jpg to IDRiD_54.jpg)
│   │   └── b. Testing Set/        (27 images: IDRiD_55.jpg to IDRiD_81.jpg)
│   └── 2. All Segmentation Groundtruths/
│       ├── a. Training Set/
│       │   ├── 1. Microaneurysms/ (e.g. IDRiD_01_MA.tif)
│       │   ├── 2. Haemorrhages/   (e.g. IDRiD_01_HE.tif)
│       │   ├── 3. Hard Exudates/  (e.g. IDRiD_01_EX.tif)
│       │   ├── 4. Soft Exudates/  (e.g. IDRiD_01_SE.tif)
│       │   └── 5. Optic Disc/     (excluded from lesion training)
│       └── b. Testing Set/
└── B. Disease Grading/
    ├── 1. Original Images/
    │   ├── a. Training Set/       (413 images: IDRiD_001.jpg to IDRiD_413.jpg)
    │   └── b. Testing Set/        (103 images: IDRiD_414.jpg to IDRiD_516.jpg)
    └── 2. Groundtruths/
        ├── a. IDRiD_Disease Grading_Training Labels.csv
        └── b. IDRiD_Disease Grading_Testing Labels.csv
```

---

## Step 6: Opening and Running the Notebooks

Execute cells sequentially using `Shift + Enter` (or click the **Play** button beside each cell).

### Execution Order:
1. Run **Notebook A** (`train_efficientnet_b0_from_scratch.ipynb`) first to produce the DR classifier (`retina_efficientnet_b0_scratch.onnx`).
2. Run **Notebook B** (`train_yolo26n_lesions_from_scratch.ipynb`) second to produce the lesion detector (`yolo26n_lesions_scratch.onnx`).

---

## Step 7: Executing Smoke Test & Pilot Run First

Both notebooks include an explicit **Pilot Benchmark** before initiating full training:
- **Single-batch Smoke Test:** Confirms tensor dimensions, gradient backpropagation, and VRAM stability without crashing.
- **Pilot Epoch Timing:** Runs exactly 1 full epoch and prints the measured duration (e.g. ~45 seconds on T4 GPU vs 40 minutes on CPU).
- **Go / No-Go Decision:** Review the projected duration (e.g. `30 epochs × 45s = ~22 minutes`) before starting the full training loop.

---

## Step 8: Full Training & Resuming from Checkpoints

During training, checkpoints are automatically saved to your Google Drive:
- **Notebook A:** Saves to `/content/drive/MyDrive/RetinaScan_Models/efficientnet_b0_scratch/best_efficientnet_b0_scratch.pth` whenever validation Quadratic Weighted Kappa (QWK) improves.
- **Notebook B:** Saves to `/content/drive/MyDrive/RetinaScan_Models/yolo26n_scratch/yolo26n_scratch_run/weights/best.pt`.

### Resuming After Disconnection:
If your session disconnects, simply re-run the setup cells and load the checkpoint:
```python
# To resume Notebook A:
checkpoint = torch.load('/content/drive/MyDrive/RetinaScan_Models/efficientnet_b0_scratch/best_efficientnet_b0_scratch.pth')
model.load_state_dict(checkpoint['model_state_dict'])
optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
start_epoch = checkpoint['epoch'] + 1
print(f"Resuming from epoch {start_epoch}")
```

---

## Step 9: Troubleshooting Disconnections, OOM & Errors

| Symptom / Error | Cause | Solution |
|---|---|---|
| `CUDA out of memory (OOM)` | Batch size is too large for 16GB VRAM. | In the DataLoader / training call, reduce `BATCH_SIZE` from 16 to 8 (or 4). |
| `FileNotFoundError: Image not found` | The unzipped dataset directory does not match expected path. | Verify dataset layout in Step 5 and run `!ls -l /content/idrid/`. |
| `Colab session disconnected (Idle Timeout)` | Browser tab closed or inactive for > 30 minutes. | Keep browser active, or click anywhere in the notebook periodically. Saved checkpoints in Drive ensure zero progress is lost. |
| `Unsupported YOLO26n identifier` | Ultralytics has no native model named `yolo26n.pt`. | The notebook builds `yolo26n.yaml` from scratch without loading pre-trained weights. |

---

## Step 10: Where Outputs & Checkpoints are Saved

All persistent outputs are written to your Google Drive:
```text
Google Drive/
└── MyDrive/
    └── RetinaScan_Models/
        ├── efficientnet_b0_scratch/
        │   ├── best_efficientnet_b0_scratch.pth    (PyTorch weights + optimizer)
        │   └── retina_efficientnet_b0_scratch.onnx (Exported ONNX model)
        └── yolo26n_scratch/
            ├── yolo26n_scratch_run/
            │   ├── weights/best.pt                 (Best detector weights)
            │   ├── confusion_matrix.png            (Validation confusion matrix)
            │   └── results.png                     (mAP and loss curves)
            └── yolo26n_lesions_scratch.onnx        (Exported ONNX detector)
```

---

## Step 11: Downloading Exported Models to Windows

Once the final ONNX export cells complete in Colab:
1. Open Google Drive in your web browser.
2. Navigate to `RetinaScan_Models/`.
3. Download the two ONNX files to your Windows PC:
   - `retina_efficientnet_b0_scratch.onnx`
   - `yolo26n_lesions_scratch.onnx`

---

## Step 12: Installing Models in Local MATLAB Project

Copy the downloaded ONNX files into your local project's models directory:
- Destination: `D:\RetinaScan_MATLAB_SIH26038\data\models\`

Verify the files are in place using PowerShell:
```powershell
Get-ChildItem -Path "D:\RetinaScan_MATLAB_SIH26038\data\models"
```

---

## Step 13: Verifying Inference in MATLAB R2024a

Open MATLAB R2024a and run the following verification script:

```matlab
% Add project paths
addpath(genpath('D:\RetinaScan_MATLAB_SIH26038'));

% 1. Test EfficientNet-B0 Classifier Import
onnxClassPath = 'D:\RetinaScan_MATLAB_SIH26038\data\models\retina_efficientnet_b0_scratch.onnx';
if exist(onnxClassPath, 'file')
    fprintf('Testing EfficientNet-B0 ONNX Import...\n');
    netClass = importNetworkFromONNX(onnxClassPath, 'OutputDataFormats', 'BC');
    disp('Classifier successfully imported into MATLAB R2024a!');
    
    % Test forward pass with dummy retinal image
    dummyImg = dlarray(single(rand(224, 224, 3, 1)), 'SSCB');
    logits = predict(netClass, dummyImg);
    probs = extractdata(softmax(logits));
    fprintf('Prediction logits shape: %s\n', mat2str(size(logits)));
    fprintf('Probabilities: %s\n', mat2str(round(probs, 4)));
else
    fprintf('Classifier model file not found at %s\n', onnxClassPath);
end

% 2. Test YOLO26n Detector Import
onnxYoloPath = 'D:\RetinaScan_MATLAB_SIH26038\data\models\yolo26n_lesions_scratch.onnx';
if exist(onnxYoloPath, 'file')
    fprintf('\nTesting YOLO26n ONNX Import...\n');
    netYolo = importNetworkFromONNX(onnxYoloPath, 'OutputDataFormats', 'BC');
    disp('YOLO26n successfully imported into MATLAB R2024a!');
    
    dummyImg1024 = dlarray(single(rand(1, 3, 1024, 1024)), 'BCSS');
    predBoxes = predict(netYolo, dummyImg1024);
    disp('YOLO forward pass executed successfully!');
else
    fprintf('YOLO model file not found at %s\n', onnxYoloPath);
end
```

---

## Step 14: How to Safely Stop and Resume Later

- **To Stop Training Gracefully:** In Colab, click the **Stop** (Interrupt execution) button on the training cell. The checkpointing logic ensures that all completed epochs are saved on your Google Drive up to the last completed epoch.
- **To Resume Later:** Restart the runtime, mount Drive, load the `.pth` file using `torch.load()`, and continue training from the saved epoch number.
