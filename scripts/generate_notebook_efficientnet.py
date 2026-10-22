"""
Generator script for Notebook A: train_efficientnet_b0_from_scratch.ipynb
Constructs a valid Jupyter Notebook JSON structure with full markdown and executable code cells.
"""

import json
import os

def create_notebook():
    nb = {
        "cells": [],
        "metadata": {
            "accelerator": "GPU",
            "colab": {
                "gpuType": "T4",
                "provenance": []
            },
            "language_info": {
                "name": "python",
                "version": "3.10.12"
            }
        },
        "nbformat": 4,
        "nbformat_minor": 2
    }

    def add_md(source):
        nb["cells"].append({
            "cell_type": "markdown",
            "metadata": {},
            "source": [line + "\n" for line in source.strip().split("\n")]
        })

    def add_code(source):
        nb["cells"].append({
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": [line + "\n" for line in source.strip().split("\n")]
        })

    # Header
    add_md("""# RetinaScan AI — EfficientNet-B0 Diabetic Retinopathy Classifier (From Scratch)
**Problem:** SIH 26038 — Explainable AI for Diabetic Retinopathy Screening in Rural India  
**Target:** 5-Class ICDR DR Grading (Grades 0–4) on IDRiD Dataset  
**Model:** EfficientNet-B0 initialized **from scratch** with random weights (`weights=None`)  
**Strict Policy:** NO ImageNet pre-training, NO reused weights from previous repositories. Every weight is randomly initialized.

---

### Objectives & Protocol
1. **Zero Data Leakage:** Use ONLY official IDRiD Training Set (413 images) for model training and stratified validation. Keep official Testing Set (103 images) strictly untouched until post-training evaluation.
2. **GPU Smoke Test & Pilot Run:** Measure real VRAM and pilot epoch duration before committing to the full schedule.
3. **Resilient Checkpointing:** Save weights, optimizer, and metadata to Google Drive to survive Colab disconnections.
4. **Comprehensive Evaluation:** Report Confusion Matrix, Macro-F1, Quadratic Weighted Kappa (QWK), and Referable DR Sensitivity/Specificity.
5. **ONNX Export:** Export to ONNX FP32 with numerical verification and provide MATLAB R2024a import instructions.""")

    # Section 1: GPU & Environment
    add_md("""## 1. Environment & GPU Verification
Verify that a GPU (e.g. NVIDIA T4, V100, or A100) is allocated in Google Colab.""")

    add_code("""import os
import sys
import time
import copy
import random
import numpy as np
import pandas as pd
from PIL import Image
import matplotlib.pyplot as plt

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms as transforms
import torchvision.models as models

# Fix seeds for reproducibility
SEED = 42
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
torch.cuda.manual_seed_all(SEED)
torch.backends.cudnn.deterministic = True

# Verify GPU
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"PyTorch Version: {torch.__version__}")
print(f"Device: {device}")
if torch.cuda.is_available():
    print(f"GPU Model: {torch.cuda.get_device_name(0)}")
    print(f"VRAM Available: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
else:
    print("WARNING: No GPU detected! Go to Runtime -> Change runtime type -> Hardware accelerator -> T4 GPU.")
""")

    # Section 2: Drive Mounting & Paths
    add_md("""## 2. Google Drive Mounting & Dataset Directory Configuration
Mount Google Drive to persist checkpoints across session disconnects.""")

    add_code("""# Mount Google Drive
try:
    from google.colab import drive
    drive.mount('/content/drive')
    CHECKPOINT_DIR = '/content/drive/MyDrive/RetinaScan_Models/efficientnet_b0_scratch'
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)
    print(f"Google Drive mounted. Checkpoints will be saved to: {CHECKPOINT_DIR}")
except Exception as e:
    print(f"Not running in Colab or Drive mount skipped: {e}")
    CHECKPOINT_DIR = './checkpoints_efficientnet_b0'
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)

import glob
import zipfile

# Robust Dataset Discovery & Auto-Unzip Logic
def locate_grading_dataset():
    # 1. Check if already unzipped locally
    candidates = [
        '/content/idrid/B. Disease Grading',
        '/content/idrid',
        '/content/drive/MyDrive/RetinaScan_Data/B. Disease Grading',
        '/content/drive/MyDrive/idrid/B. Disease Grading',
        '/content/drive/MyDrive/idrid',
        '/content/drive/MyDrive/B. Disease Grading'
    ]
    for c in candidates:
        if os.path.exists(os.path.join(c, '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv')):
            print(f"--> Found dataset directly at: {c}")
            return c

    # 2. Check for zip files to auto-extract
    zip_candidates = [
        '/content/idrid_grading.zip',
        '/content/drive/MyDrive/RetinaScan_Data/idrid_grading.zip',
        '/content/drive/MyDrive/idrid_grading.zip',
        '/content/drive/MyDrive/idrid.zip'
    ]
    for z in zip_candidates:
        if os.path.exists(z):
            print(f"--> Found zip archive at {z}. Auto-extracting to /content/idrid/ ...")
            os.makedirs('/content/idrid', exist_ok=True)
            with zipfile.ZipFile(z, 'r') as zip_ref:
                zip_ref.extractall('/content/idrid')
            print("--> Extraction completed!")
            for c in ['/content/idrid/B. Disease Grading', '/content/idrid']:
                if os.path.exists(os.path.join(c, '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv')):
                    return c

    # 3. Recursive search in Drive and /content
    print("Searching for 'a. IDRiD_Disease Grading_Training Labels.csv' across Drive and local disk...")
    matches = glob.glob('/content/**/a. IDRiD_Disease Grading_Training Labels.csv', recursive=True)
    if not matches:
        matches = glob.glob('/content/drive/MyDrive/**/a. IDRiD_Disease Grading_Training Labels.csv', recursive=True)
    
    if matches:
        csv_path = matches[0]
        # Dataset root is two directories up from the CSV
        data_root = os.path.abspath(os.path.join(os.path.dirname(csv_path), '..'))
        print(f"--> Discovered dataset root at: {data_root}")
        return data_root

    # 4. If not found, list available directories to assist user
    print("\\n[ERROR] Could not automatically locate IDRiD grading dataset!")
    print("Files found in /content:")
    print(" ", os.listdir('/content'))
    if os.path.exists('/content/drive/MyDrive'):
        print("Folders in /content/drive/MyDrive:")
        print(" ", [f for f in os.listdir('/content/drive/MyDrive') if not f.startswith('.')][:10])
    raise FileNotFoundError("IDRiD training CSV not found. Please upload 'idrid_grading.zip' to Google Drive or extract it to /content/idrid/.")

DATA_ROOT = locate_grading_dataset()
print(f"\\nDATA_ROOT verified and active: {DATA_ROOT}")
""")

    # Section 3: Data Loading & Stratified Split
    add_md("""## 3. Dataset Inspection & Stratified Validation Split
We inspect `a. IDRiD_Disease Grading_Training Labels.csv`, report the class distribution, and construct an 80/20 stratified split from the training data. The official test set remains locked.""")

    add_code("""from sklearn.model_selection import train_test_split

train_csv_path = os.path.join(DATA_ROOT, '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv')
test_csv_path = os.path.join(DATA_ROOT, '2. Groundtruths', 'b. IDRiD_Disease Grading_Testing Labels.csv')

train_img_dir = os.path.join(DATA_ROOT, '1. Original Images', 'a. Training Set')
test_img_dir = os.path.join(DATA_ROOT, '1. Original Images', 'b. Testing Set')

# Read training annotations
df_train_full = pd.read_csv(train_csv_path)
df_train_full = df_train_full.dropna(subset=['Retinopathy grade'])
df_train_full['Retinopathy grade'] = df_train_full['Retinopathy grade'].astype(int)

# Normalize column names
img_col = 'Image name'
label_col = 'Retinopathy grade'

print(f"Total Official Training Images: {len(df_train_full)}")
print("Class Distribution in Official Training Split:")
class_counts = df_train_full[label_col].value_counts().sort_index()
for grade, count in class_counts.items():
    pct = count / len(df_train_full) * 100
    print(f"  Grade {grade}: {count:3d} images ({pct:5.1f}%)")

# Create Stratified 80/20 Split from Official Training Set ONLY
train_df, val_df = train_test_split(
    df_train_full,
    test_size=0.20,
    stratify=df_train_full[label_col],
    random_state=SEED
)

print(f"\\nStratified Split:")
print(f"  Training Split:   {len(train_df)} images")
print(f"  Validation Split: {len(val_df)} images")

# Read test annotations (locked for post-training evaluation)
df_test = pd.read_csv(test_csv_path).dropna(subset=['Retinopathy grade'])
df_test['Retinopathy grade'] = df_test['Retinopathy grade'].astype(int)
print(f"  Held-Out Test Set (UNTOUCHED): {len(df_test)} images")
""")

    # Section 4: Dataset & DataLoader
    add_md("""## 4. PyTorch Dataset & Augmentation Pipeline
Because training from scratch with random weights requires maximum feature diversity, we apply robust geometric and color augmentations to the training partition.""")

    add_code("""class RetinalFundusDataset(Dataset):
    def __init__(self, df, img_dir, transform=None):
        self.df = df.reset_index(drop=True)
        self.img_dir = img_dir
        self.transform = transform

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        img_name = str(row['Image name']).strip()
        if not img_name.endswith(('.jpg', '.png', '.tif', '.jpeg')):
            img_path = os.path.join(self.img_dir, f"{img_name}.jpg")
        else:
            img_path = os.path.join(self.img_dir, img_name)

        if not os.path.exists(img_path):
            raise FileNotFoundError(f"Image not found at path: {img_path}")

        image = Image.open(img_path).convert('RGB')
        label = int(row['Retinopathy grade'])

        if self.transform:
            image = self.transform(image)

        return image, label, img_name

# Image Resolution: 224x224 (or 300x300)
INPUT_SIZE = 224

train_transforms = transforms.Compose([
    transforms.Resize((INPUT_SIZE, INPUT_SIZE)),
    transforms.RandomHorizontalFlip(p=0.5),
    transforms.RandomVerticalFlip(p=0.5),
    transforms.RandomRotation(degrees=25),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.1),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

eval_transforms = transforms.Compose([
    transforms.Resize((INPUT_SIZE, INPUT_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

train_dataset = RetinalFundusDataset(train_df, train_img_dir, transform=train_transforms)
val_dataset   = RetinalFundusDataset(val_df, train_img_dir, transform=eval_transforms)
test_dataset  = RetinalFundusDataset(df_test, test_img_dir, transform=eval_transforms)

BATCH_SIZE = 16
NUM_WORKERS = 2

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True, num_workers=NUM_WORKERS, pin_memory=True)
val_loader   = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=NUM_WORKERS, pin_memory=True)
test_loader  = DataLoader(test_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=NUM_WORKERS, pin_memory=True)

print(f"DataLoaders initialized: {len(train_loader)} train batches, {len(val_loader)} val batches.")
""")

    # Section 5: Model Definition
    add_md("""## 5. Model Architecture: EfficientNet-B0 Initialized from Scratch
**Strict Mandate:** `weights=None` ensures all weights are initialized randomly using PyTorch defaults. No ImageNet features exist in this network.""")

    add_code("""def create_scratch_efficientnet(num_classes=5):
    # Initialize from scratch (weights=None)
    model = models.efficientnet_b0(weights=None)
    
    # Replace classification head
    in_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.3, inplace=True),
        nn.Linear(in_features, num_classes)
    )
    
    # Kaiming Normal initialization for head
    nn.init.kaiming_normal_(model.classifier[1].weight, mode='fan_out', nonlinearity='relu')
    nn.init.constant_(model.classifier[1].bias, 0.0)
    
    return model

model = create_scratch_efficientnet(num_classes=5)
model = model.to(device)

total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"Model: EfficientNet-B0 (FROM SCRATCH)")
print(f"Total Parameters:     {total_params:,}")
print(f"Trainable Parameters: {trainable_params:,}")
""")

    # Section 6: Smoke Test & Pilot Run
    add_md("""## 6. GPU Smoke Test & Pilot Epoch Measurement
We perform a single-batch forward/backward pass and measure 1 full pilot epoch to verify memory consumption and calculate the projected training duration.""")

    add_code("""# 1. Single-Batch Smoke Test
print("Running single-batch GPU smoke test...")
sample_imgs, sample_labels, _ = next(iter(train_loader))
sample_imgs = sample_imgs.to(device)
sample_labels = sample_labels.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)

optimizer.zero_grad()
outputs = model(sample_imgs)
loss = criterion(outputs, sample_labels)
loss.backward()
optimizer.step()

torch.cuda.synchronize()
peak_mem = torch.cuda.max_memory_allocated() / 1e6
print(f"  Smoke Test Passed! Loss: {loss.item():.4f}")
print(f"  Peak VRAM: {peak_mem:.1f} MB")

# 2. Pilot Epoch Timing
print("\\nRunning Pilot Epoch on full training set (330 images)...")
model.train()
t0 = time.time()
running_loss = 0.0

for imgs, labels, _ in train_loader:
    imgs, labels = imgs.to(device), labels.to(device)
    optimizer.zero_grad()
    outs = model(imgs)
    l = criterion(outs, labels)
    l.backward()
    optimizer.step()
    running_loss += l.item() * imgs.size(0)

torch.cuda.synchronize()
epoch_time = time.time() - t0
print(f"  Pilot Epoch Duration: {epoch_time:.2f} seconds ({epoch_time/60:.2f} minutes)")
print(f"  Projected 30-Epoch Training Time on Colab GPU: {30 * epoch_time / 60:.1f} minutes")
""")

    # Section 7: Full Training Loop with Google Drive Checkpointing
    add_md("""## 7. Training Loop with Class Weighting & Resilient Checkpointing
We compute inverse class frequencies to penalize rare grade errors, track Quadratic Weighted Kappa (QWK), and save the best checkpoint to Google Drive.""")

    add_code("""from sklearn.metrics import cohen_kappa_score, f1_score

# Compute Class Weights for Imbalance
labels_array = train_df[label_col].values
class_sample_counts = np.bincount(labels_array, minlength=5)
weights = 1.0 / (class_sample_counts + 1e-5)
weights = weights / weights.sum()
class_weights_tensor = torch.tensor(weights, dtype=torch.float).to(device)
print(f"Class Weights: {class_weights_tensor.cpu().numpy()}")

criterion = nn.CrossEntropyLoss(weight=class_weights_tensor)
optimizer = optim.AdamW(model.parameters(), lr=5e-4, weight_decay=1e-3)
scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=30, eta_min=1e-6)

NUM_EPOCHS = 30
best_val_qwk = -1.0
history = {'train_loss': [], 'val_loss': [], 'val_qwk': [], 'val_macro_f1': []}

for epoch in range(1, NUM_EPOCHS + 1):
    # Training Phase
    model.train()
    train_loss = 0.0
    for imgs, labels, _ in train_loader:
        imgs, labels = imgs.to(device), labels.to(device)
        optimizer.zero_grad()
        outs = model(imgs)
        loss = criterion(outs, labels)
        loss.backward()
        optimizer.step()
        train_loss += loss.item() * imgs.size(0)
    
    scheduler.step()
    train_loss /= len(train_loader.dataset)
    
    # Validation Phase
    model.eval()
    val_loss = 0.0
    all_preds, all_targets = [], []
    with torch.no_grad():
        for imgs, labels, _ in val_loader:
            imgs, labels = imgs.to(device), labels.to(device)
            outs = model(imgs)
            loss = criterion(outs, labels)
            val_loss += loss.item() * imgs.size(0)
            preds = torch.argmax(outs, dim=1)
            all_preds.extend(preds.cpu().numpy())
            all_targets.extend(labels.cpu().numpy())
            
    val_loss /= len(val_loader.dataset)
    val_qwk = cohen_kappa_score(all_targets, all_preds, weights='quadratic')
    val_f1 = f1_score(all_targets, all_preds, average='macro', zero_division=0)
    
    history['train_loss'].append(train_loss)
    history['val_loss'].append(val_loss)
    history['val_qwk'].append(val_qwk)
    history['val_macro_f1'].append(val_f1)
    
    print(f"Epoch [{epoch:02d}/{NUM_EPOCHS:02d}] Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | Val QWK: {val_qwk:.4f} | Val Macro-F1: {val_f1:.4f}")
    
    # Checkpointing: Save Best Model
    if val_qwk > best_val_qwk:
        best_val_qwk = val_qwk
        checkpoint_path = os.path.join(CHECKPOINT_DIR, 'best_efficientnet_b0_scratch.pth')
        torch.save({
            'epoch': epoch,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'val_qwk': val_qwk,
            'val_macro_f1': val_f1,
            'history': history,
            'class_mapping': {0: 'No DR', 1: 'Mild', 2: 'Moderate', 3: 'Severe', 4: 'Proliferative'}
        }, checkpoint_path)
        print(f"  --> Saved new best checkpoint to {checkpoint_path} (Val QWK: {val_qwk:.4f})")
""")

    # Section 8: Evaluation on Held-Out Test Set
    add_md("""## 8. Evaluation on Untouched Official IDRiD Test Set
Load the best checkpoint and evaluate on the 103 test images. Compute complete classification metrics and Referable DR Sensitivity/Specificity.""")

    add_code("""from sklearn.metrics import classification_report, confusion_matrix, balanced_accuracy_score

# Load Best Checkpoint
best_cp_path = os.path.join(CHECKPOINT_DIR, 'best_efficientnet_b0_scratch.pth')
checkpoint = torch.load(best_cp_path, map_location=device)
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()
print(f"Loaded best checkpoint from Epoch {checkpoint['epoch']} with Val QWK: {checkpoint['val_qwk']:.4f}")

# Run inference on untouched test set
test_preds, test_targets, test_probs = [], [], []
with torch.no_grad():
    for imgs, labels, _ in test_loader:
        imgs = imgs.to(device)
        outs = model(imgs)
        probs = torch.softmax(outs, dim=1)
        preds = torch.argmax(probs, dim=1)
        test_preds.extend(preds.cpu().numpy())
        test_targets.extend(labels.numpy())
        test_probs.extend(probs.cpu().numpy())

test_preds = np.array(test_preds)
test_targets = np.array(test_targets)
test_probs = np.array(test_probs)

# 1. Classification Report
target_names = ['Grade 0 (None)', 'Grade 1 (Mild)', 'Grade 2 (Moderate)', 'Grade 3 (Severe)', 'Grade 4 (PDR)']
print("\\n" + "="*60)
print("OFFICIAL IDRiD TEST SPLIT — CLASSIFICATION REPORT")
print("="*60)
print(classification_report(test_targets, test_preds, target_names=target_names, digits=4, zero_division=0))

# 2. Summary Metrics
test_qwk = cohen_kappa_score(test_targets, test_preds, weights='quadratic')
test_bal_acc = balanced_accuracy_score(test_targets, test_preds)
print(f"Test Quadratic Weighted Kappa (QWK): {test_qwk:.4f}")
print(f"Test Balanced Accuracy:             {test_bal_acc:.4f}")

# 3. Referable DR (Grade >= 2)
ref_true = (test_targets >= 2).astype(int)
ref_pred = (test_preds >= 2).astype(int)
tn, fp, fn, tp = confusion_matrix(ref_true, ref_pred).ravel()
sens = tp / (tp + fn) if (tp + fn) > 0 else 0.0
spec = tn / (tn + fp) if (tn + fp) > 0 else 0.0
print(f"\\nReferable DR Screening Metrics (Threshold: Grade >= 2):")
print(f"  Sensitivity (Recall): {sens*100:.2f}% (Target: >= 90.0%)")
print(f"  Specificity:          {spec*100:.2f}% (Target: >= 85.0%)")
""")

    # Section 9: ONNX Export & Verification
    add_md("""## 9. ONNX Export & Numerical Verification
Export to ONNX format with dynamic batch dimensions and verify that ONNX Runtime produces identical numerical outputs to PyTorch.""")

    add_code("""import onnx
import onnxruntime as ort

onnx_export_path = os.path.join(CHECKPOINT_DIR, 'retina_efficientnet_b0_scratch.onnx')
dummy_input = torch.randn(1, 3, INPUT_SIZE, INPUT_SIZE, device=device)

# Export Model
model.eval()
torch.onnx.export(
    model,
    dummy_input,
    onnx_export_path,
    export_params=True,
    opset_version=14,
    do_constant_folding=True,
    input_names=['input_image'],
    output_names=['logits'],
    dynamic_axes={
        'input_image': {0: 'batch_size'},
        'logits': {0: 'batch_size'}
    }
)
print(f"ONNX model exported to: {onnx_export_path}")
print(f"File Size: {os.path.getsize(onnx_export_path) / 1e6:.2f} MB")

# Verify ONNX model integrity
onnx_model = onnx.load(onnx_export_path)
onnx.checker.check_model(onnx_model)
print("ONNX model verification PASSED!")

# Numerical Equivalence Check
ort_session = ort.InferenceSession(onnx_export_path)
dummy_np = dummy_input.cpu().numpy()
ort_inputs = {ort_session.get_inputs()[0].name: dummy_np}
ort_outs = ort_session.run(None, ort_inputs)[0]

with torch.no_grad():
    torch_outs = model(dummy_input).cpu().numpy()

max_diff = np.max(np.abs(torch_outs - ort_outs))
print(f"Maximum Absolute Difference (PyTorch vs ONNX): {max_diff:.6e}")
assert max_diff < 1e-4, "Numerical divergence exceeds tolerance!"
print("Numerical equivalence CONFIRMED (Diff < 1e-4)!")
""")

    # Section 10: MATLAB Import Instructions
    add_md("""## 10. MATLAB R2024a Import Instructions
After downloading `retina_efficientnet_b0_scratch.onnx` to your local machine, place it in:
`D:\\RetinaScan_MATLAB_SIH26038\\data\\models\\retina_efficientnet_b0_scratch.onnx`

Then execute the following MATLAB commands:
```matlab
% 1. Import ONNX Model into MATLAB R2024a
onnxPath = 'D:\\RetinaScan_MATLAB_SIH26038\\data\\models\\retina_efficientnet_b0_scratch.onnx';
net = importNetworkFromONNX(onnxPath, 'OutputDataFormats', 'BC');

% 2. Inspect Input and Layers
disp(net);

% 3. Run Inference on a Retinal Image
img = imread('D:\\sih2026\\retino\\data\\samples\\idrid_samples\\idrid_grade_2.jpg');
imgResized = imresize(img, [224, 224]);
imgSingle = single(imgResized) / 255.0;

% Normalize using ImageNet statistics
meanVals = reshape([0.485, 0.456, 0.406], [1, 1, 3]);
stdVals  = reshape([0.229, 0.224, 0.225], [1, 1, 3]);
imgNorm = (imgSingle - meanVals) ./ stdVals;

% dlarray format [H, W, C, B]
dlImg = dlarray(imgNorm, 'SSCB');
logits = predict(net, dlImg);
probabilities = extractdata(softmax(logits));

grades = {'No DR (0)', 'Mild (1)', 'Moderate (2)', 'Severe (3)', 'Proliferative (4)'};
[maxProb, predIdx] = max(probabilities);
fprintf('Predicted Grade: %s (Confidence: %.2f%%)\\n', grades{predIdx}, maxProb * 100);
```""")

    # Save notebook
    out_path = r"D:\RetinaScan_MATLAB_SIH26038\notebooks\train_efficientnet_b0_from_scratch.ipynb"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2)
    print(f"Successfully generated Notebook A at: {out_path}")

if __name__ == "__main__":
    create_notebook()
