"""
Generator script for Notebook B: train_yolo26n_lesions_from_scratch.ipynb & train_yolo11n_lesions_from_scratch.ipynb
Uses official Ultralytics YOLO11n (yolo11n.yaml) initialized completely FROM SCRATCH with random weights.
"""

import json
import os

def create_yolo11_notebook():
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
    add_md("""# RetinaScan AI — Official YOLO11n Retinal Lesion Detector (From Scratch)
**Problem:** SIH 26038 — Explainable AI for Diabetic Retinopathy Screening in Rural India  
**Target:** Multi-Class Retinal Lesion Bounding Box Detection on IDRiD Lesion Segmentation Dataset  
**Model Architecture:** Official **Ultralytics YOLO11n** (`yolo11n.yaml`)  
**Strict Policy:** NO Pretrained Weights (No COCO, No ImageNet, No Old Weights). Initialized 100% from scratch with random weights (`YOLO('yolo11n.yaml')`).

---

### Why YOLO11n?
- **Official & State-of-the-Art:** YOLO11 is the official modern release by Ultralytics, featuring enhanced C3k2 building blocks, SPPF pooling, and optimized attention heads for high-resolution vision tasks.
- **Random Initialization from Scratch:** By loading the architecture definition `YOLO('yolo11n.yaml')` instead of a pre-trained `.pt` weight file, the neural network begins with 100% randomly initialized parameters.
- **Lesion Classes Handled (4 pathological targets):**
  - Class 0: `Microaneurysms` (MA)
  - Class 1: `Haemorrhages` (HE)
  - Class 2: `Hard Exudates` (EX)
  - Class 3: `Soft Exudates` (SE) (Cotton Wool Spots)
  - *Optic Disc (`OD`) is excluded* as an anatomical landmark.

---

### Objectives & Protocol
1. **Intelligent Dataset Discovery & Auto-Unzip:** Detects `idrid_segmentation.zip` anywhere in your Google Drive or `/content/` and unzips automatically.
2. **Mask-to-BBox Conversion:** Convert pixel-level binary masks into normalized YOLO format with noise filtering.
3. **Partition Preservation:** 54 training images partitioned into 43 train / 11 val. 27 test images strictly kept untouched until evaluation.
4. **Visual Verification:** Render bounding boxes overlaid on raw fundus images before training.
5. **GPU Smoke Test & Pilot Run:** Benchmark 1 epoch on GPU before full execution.
6. **ONNX Export:** Export to ONNX format and provide MATLAB R2024a import instructions.""")

    # Section 1: Environment & Framework Verification
    add_md("""## 1. Environment & Framework Audit
Install latest `ultralytics` (which provides official YOLO11 support) and verify GPU.""")

    add_code("""!pip install -q "ultralytics>=8.3.0" opencv-python-headless pillow pandas matplotlib pyyaml onnx onnxruntime

import os
import sys
import glob
import time
import shutil
import random
import numpy as np
import pandas as pd
from PIL import Image
import cv2
import yaml
import matplotlib.pyplot as plt

import torch
import ultralytics
from ultralytics import YOLO

# Fix random seed
SEED = 42
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)

print(f"PyTorch Version: {torch.__version__}")
print(f"Ultralytics Version: {ultralytics.__version__} (YOLO11 Supported)")
print(f"CUDA Available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU Model: {torch.cuda.get_device_name(0)}")
    print(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
else:
    print("WARNING: GPU not detected. Enable GPU via Runtime -> Change runtime type.")
""")

    # Section 2: Drive Mounting & Paths
    add_md("""## 2. Google Drive Mounting & Dataset Auto-Discovery
Mount Google Drive to persist converted dataset annotations and model checkpoints. Automatically discovers and extracts `idrid_segmentation.zip`.""")

    add_code("""try:
    from google.colab import drive
    drive.mount('/content/drive')
    CHECKPOINT_DIR = '/content/drive/MyDrive/RetinaScan_Models/yolo11n_scratch'
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)
    print(f"Google Drive mounted. Checkpoints will be saved to: {CHECKPOINT_DIR}")
except Exception as e:
    print(f"Drive mount skipped: {e}")
    CHECKPOINT_DIR = './checkpoints_yolo11n'
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)

import glob
import zipfile

# Robust Dataset Discovery & Auto-Unzip Logic for Segmentation
def locate_segmentation_dataset():
    # 1. Check if already unzipped locally
    candidates = [
        '/content/idrid/A. Segmentation',
        '/content/idrid',
        '/content/drive/MyDrive/RetinaScan_Data/A. Segmentation',
        '/content/drive/MyDrive/idrid/A. Segmentation',
        '/content/drive/MyDrive/idrid',
        '/content/drive/MyDrive/A. Segmentation'
    ]
    for c in candidates:
        if os.path.exists(os.path.join(c, '1. Original Images', 'a. Training Set')):
            print(f"--> Found segmentation dataset directly at: {c}")
            return c

    # 2. Check for zip files to auto-extract
    zip_candidates = [
        '/content/idrid_segmentation.zip',
        '/content/drive/MyDrive/RetinaScan_Data/idrid_segmentation.zip',
        '/content/drive/MyDrive/idrid_segmentation.zip'
    ]
    for z in zip_candidates:
        if os.path.exists(z):
            print(f"--> Found zip archive at {z}. Auto-extracting to /content/idrid/ ...")
            os.makedirs('/content/idrid', exist_ok=True)
            with zipfile.ZipFile(z, 'r') as zip_ref:
                zip_ref.extractall('/content/idrid')
            print("--> Extraction completed!")
            for c in ['/content/idrid/A. Segmentation', '/content/idrid']:
                if os.path.exists(os.path.join(c, '1. Original Images', 'a. Training Set')):
                    return c

    # 3. Recursive search in Drive and /content
    print("Searching for segmentation images across Drive and local disk...")
    matches = glob.glob('/content/**/IDRiD_01.jpg', recursive=True)
    if not matches:
        matches = glob.glob('/content/drive/MyDrive/**/IDRiD_01.jpg', recursive=True)
    
    if matches:
        for m in matches:
            p_dir = os.path.dirname(m)
            if 'Original Images' in p_dir:
                data_root = os.path.abspath(os.path.join(p_dir, '..', '..'))
                print(f"--> Discovered segmentation root at: {data_root}")
                return data_root

    # 4. If not found, list available directories
    print("\\n[ERROR] Could not automatically locate IDRiD segmentation dataset!")
    print("Files in /content:")
    print(" ", os.listdir('/content'))
    if os.path.exists('/content/drive/MyDrive'):
        print("Folders in /content/drive/MyDrive:")
        print(" ", [f for f in os.listdir('/content/drive/MyDrive') if not f.startswith('.')][:10])
    raise FileNotFoundError("IDRiD segmentation dataset not found. Please upload 'idrid_segmentation.zip' to Google Drive or extract to /content/idrid/.")

DATA_ROOT = locate_segmentation_dataset()
print(f"\\nDATA_ROOT verified and active: {DATA_ROOT}")
""")

    # Section 3: Mask-to-BBox Conversion Engine
    add_md("""## 3. Mask-to-Bounding Box Conversion Engine
Convert pixel-level binary masks into normalized YOLO format `[class_id, x_center, y_center, width, height]`.""")

    add_code("""def convert_masks_to_yolo(data_root, output_dir):
    os.makedirs(os.path.join(output_dir, 'images', 'train'), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'images', 'val'), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'images', 'test'), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'labels', 'train'), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'labels', 'val'), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'labels', 'test'), exist_ok=True)

    lesion_configs = [
        ('1. Microaneurysms', '_MA', 0),
        ('2. Haemorrhages',   '_HE', 1),
        ('3. Hard Exudates',  '_EX', 2),
        ('4. Soft Exudates',  '_SE', 3)
    ]

    # Process Training Set (54 images) -> 43 Train / 11 Val
    train_img_dir = os.path.join(data_root, '1. Original Images', 'a. Training Set')
    train_mask_dir = os.path.join(data_root, '2. All Segmentation Groundtruths', 'a. Training Set')
    
    train_img_files = sorted(glob.glob(os.path.join(train_img_dir, '*.jpg')))
    print(f"Found {len(train_img_files)} original training images.")
    
    random.seed(SEED)
    shuffled_files = train_img_files.copy()
    random.shuffle(shuffled_files)
    
    val_count = 11
    val_files = set(shuffled_files[:val_count])
    
    stats = {'train_boxes': 0, 'val_boxes': 0, 'test_boxes': 0, 'by_class': {0:0, 1:0, 2:0, 3:0}}

    for img_path in train_img_files:
        base_name = os.path.splitext(os.path.basename(img_path))[0]
        split = 'val' if img_path in val_files else 'train'
        
        img = cv2.imread(img_path)
        if img is None:
            continue
        h, w, _ = img.shape
        
        dest_img_path = os.path.join(output_dir, 'images', split, f"{base_name}.jpg")
        shutil.copyfile(img_path, dest_img_path)
        
        bboxes = []
        for folder_name, suffix, class_id in lesion_configs:
            mask_pattern = os.path.join(train_mask_dir, folder_name, f"{base_name}*{suffix}*.tif")
            matches = glob.glob(mask_pattern)
            if not matches:
                continue
                
            mask = cv2.imread(matches[0], cv2.IMREAD_GRAYSCALE)
            if mask is None or np.max(mask) == 0:
                continue
                
            if mask.shape != (h, w):
                mask = cv2.resize(mask, (w, h), interpolation=cv2.INTER_NEAREST)
                
            num_labels, labels, cc_stats, centroids = cv2.connectedComponentsWithStats(mask)
            for i in range(1, num_labels):
                area = cc_stats[i, cv2.CC_STAT_AREA]
                bw = cc_stats[i, cv2.CC_STAT_WIDTH]
                bh = cc_stats[i, cv2.CC_STAT_HEIGHT]
                
                # Noise filtering
                if area < 6 or bw < 3 or bh < 3:
                    continue
                    
                x = cc_stats[i, cv2.CC_STAT_LEFT]
                y = cc_stats[i, cv2.CC_STAT_TOP]
                
                x_center = (x + bw / 2.0) / w
                y_center = (y + bh / 2.0) / h
                nw = bw / float(w)
                nh = bh / float(h)
                
                bboxes.append(f"{class_id} {x_center:.6f} {y_center:.6f} {nw:.6f} {nh:.6f}")
                stats[f"{split}_boxes"] += 1
                stats['by_class'][class_id] += 1
                
        label_file = os.path.join(output_dir, 'labels', split, f"{base_name}.txt")
        with open(label_file, 'w') as f:
            f.write("\\n".join(bboxes))

    # Process Test Set (27 images)
    test_img_dir = os.path.join(data_root, '1. Original Images', 'b. Testing Set')
    test_mask_dir = os.path.join(data_root, '2. All Segmentation Groundtruths', 'b. Testing Set')
    test_img_files = sorted(glob.glob(os.path.join(test_img_dir, '*.jpg')))
    print(f"Found {len(test_img_files)} original testing images (held-out).")

    for img_path in test_img_files:
        base_name = os.path.splitext(os.path.basename(img_path))[0]
        img = cv2.imread(img_path)
        if img is None:
            continue
        h, w, _ = img.shape
        dest_img_path = os.path.join(output_dir, 'images', 'test', f"{base_name}.jpg")
        shutil.copyfile(img_path, dest_img_path)
        
        bboxes = []
        for folder_name, suffix, class_id in lesion_configs:
            mask_pattern = os.path.join(test_mask_dir, folder_name, f"{base_name}*{suffix}*.tif")
            matches = glob.glob(mask_pattern)
            if not matches:
                continue
            mask = cv2.imread(matches[0], cv2.IMREAD_GRAYSCALE)
            if mask is None or np.max(mask) == 0:
                continue
            if mask.shape != (h, w):
                mask = cv2.resize(mask, (w, h), interpolation=cv2.INTER_NEAREST)
            num_labels, labels, cc_stats, centroids = cv2.connectedComponentsWithStats(mask)
            for i in range(1, num_labels):
                if cc_stats[i, cv2.CC_STAT_AREA] < 6 or cc_stats[i, cv2.CC_STAT_WIDTH] < 3 or cc_stats[i, cv2.CC_STAT_HEIGHT] < 3:
                    continue
                x = cc_stats[i, cv2.CC_STAT_LEFT]
                y = cc_stats[i, cv2.CC_STAT_TOP]
                bw = cc_stats[i, cv2.CC_STAT_WIDTH]
                bh = cc_stats[i, cv2.CC_STAT_HEIGHT]
                x_center = (x + bw / 2.0) / w
                y_center = (y + bh / 2.0) / h
                bboxes.append(f"{class_id} {x_center:.6f} {y_center:.6f} {bw/float(w):.6f} {bh/float(h):.6f}")
                stats['test_boxes'] += 1
                
        label_file = os.path.join(output_dir, 'labels', 'test', f"{base_name}.txt")
        with open(label_file, 'w') as f:
            f.write("\\n".join(bboxes))

    return stats

YOLO_DATA_DIR = '/content/yolo_idrid_data'
stats = convert_masks_to_yolo(DATA_ROOT, YOLO_DATA_DIR)
print("\\nConversion Completed!")
print(f"  Training BBoxes:   {stats['train_boxes']}")
print(f"  Validation BBoxes: {stats['val_boxes']}")
print(f"  Testing BBoxes:    {stats['test_boxes']}")
print(f"  Class 0 (MA): {stats['by_class'][0]} | Class 1 (HE): {stats['by_class'][1]} | Class 2 (EX): {stats['by_class'][2]} | Class 3 (SE): {stats['by_class'][3]}")
""")

    # Section 4: Visual Sample Inspection
    add_md("""## 4. Visual Inspection of Converted Annotations
Render bounding boxes directly onto retinal images to verify coordinate normalization and alignment before model training.""")

    add_code("""def plot_yolo_samples(image_dir, label_dir, num_samples=3):
    class_names = {0: 'MA', 1: 'HE', 2: 'EX', 3: 'SE'}
    colors = {0: (0, 255, 255), 1: (0, 0, 255), 2: (0, 255, 0), 3: (255, 0, 255)}
    
    img_files = glob.glob(os.path.join(image_dir, '*.jpg'))[:num_samples]
    fig, axes = plt.subplots(1, len(img_files), figsize=(18, 6))
    if len(img_files) == 1:
        axes = [axes]
        
    for ax, img_p in zip(axes, img_files):
        base = os.path.splitext(os.path.basename(img_p))[0]
        lbl_p = os.path.join(label_dir, f"{base}.txt")
        img = cv2.imread(img_p)
        h, w, _ = img.shape
        
        if os.path.exists(lbl_p):
            with open(lbl_p, 'r') as f:
                lines = f.readlines()
            for line in lines:
                parts = line.strip().split()
                if len(parts) == 5:
                    cls_id = int(parts[0])
                    xc, yc, bw, bh = map(float, parts[1:])
                    x1 = int((xc - bw/2.0) * w)
                    y1 = int((yc - bh/2.0) * h)
                    x2 = int((xc + bw/2.0) * w)
                    y2 = int((yc + bh/2.0) * h)
                    cv2.rectangle(img, (x1, y1), (x2, y2), colors.get(cls_id, (255, 255, 255)), 4)
                    
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        ax.imshow(img_rgb)
        ax.set_title(f"{base} (BBoxes Rendered)")
        ax.axis('off')
        
    plt.tight_layout()
    plt.show()

plot_yolo_samples(
    os.path.join(YOLO_DATA_DIR, 'images', 'train'),
    os.path.join(YOLO_DATA_DIR, 'labels', 'train'),
    num_samples=3
)
""")

    # Section 5: YAML Config & YOLO11n Initialization
    add_md("""## 5. Dataset YAML & Official YOLO11n Initialization (From Scratch)
We configure `dataset.yaml` with our 4 retinal lesion classes and initialize official **YOLO11n** (`yolo11n.yaml`) with **100% random weights**.""")

    add_code("""# 1. Create dataset.yaml
dataset_yaml = {
    'path': YOLO_DATA_DIR,
    'train': 'images/train',
    'val': 'images/val',
    'test': 'images/test',
    'names': {
        0: 'Microaneurysm',
        1: 'Haemorrhage',
        2: 'Hard_Exudate',
        3: 'Soft_Exudate'
    }
}

dataset_yaml_path = os.path.join(YOLO_DATA_DIR, 'dataset.yaml')
with open(dataset_yaml_path, 'w') as f:
    yaml.dump(dataset_yaml, f)
print(f"Wrote dataset.yaml to {dataset_yaml_path}")

# 2. Initialize official YOLO11n from scratch (weights=None)
# Passing 'yolo11n.yaml' instructs Ultralytics to construct the official YOLO11-nano architecture
# with randomly initialized weights, without downloading or loading any COCO pretrained .pt weights!
print("\\nInitializing official YOLO11n from architecture YAML (ZERO pretrained weights)...")
model = YOLO('yolo11n.yaml')
print("Official YOLO11n constructed successfully with random weights!")
""")

    # Section 6: Smoke Test & Pilot Run
    add_md("""## 6. GPU Smoke Test & Pilot Epoch Measurement
Run 1 pilot training epoch on the GPU to measure execution speed and VRAM usage before starting the full run.""")

    add_code("""print("Running 1 Pilot Training Epoch on GPU...")
t0 = time.time()
pilot_results = model.train(
    data=dataset_yaml_path,
    epochs=1,
    imgsz=1024,
    batch=4,
    device=0 if torch.cuda.is_available() else 'cpu',
    workers=2,
    save=False,
    plots=False,
    verbose=True
)
pilot_duration = time.time() - t0
print(f"\\nPilot Epoch Finished in {pilot_duration:.2f} seconds ({pilot_duration/60:.2f} minutes).")
print(f"Projected 50-Epoch Duration on Colab GPU: {50 * pilot_duration / 60:.1f} minutes.")
""")

    # Section 7: Full Training Loop
    add_md("""## 7. Full Training Loop with Google Drive Checkpointing
Train for 50 epochs, saving checkpoints and curves to Google Drive.""")

    add_code("""# Re-initialize official YOLO11n from scratch for a clean 50-epoch run
model = YOLO('yolo11n.yaml')

PROJECT_DIR = CHECKPOINT_DIR
EXPERIMENT_NAME = 'yolo11n_scratch_run'

print(f"Starting 50-Epoch Training Run for YOLO11n...")
print(f"Checkpoints will be saved to: {PROJECT_DIR}/{EXPERIMENT_NAME}")

train_results = model.train(
    data=dataset_yaml_path,
    epochs=50,
    imgsz=1024,
    batch=4,
    device=0 if torch.cuda.is_available() else 'cpu',
    workers=2,
    project=PROJECT_DIR,
    name=EXPERIMENT_NAME,
    save=True,
    save_period=5,
    patience=15,
    plots=True,
    verbose=True
)

print("\\nTraining Completed successfully!")
""")

    # Section 8: Evaluation on Held-Out Test Split
    add_md("""## 8. Evaluation on Untouched Official IDRiD Test Set
Evaluate detection performance using standard mAP metrics on the 27 held-out test images.""")

    add_code("""best_weight_path = os.path.join(PROJECT_DIR, EXPERIMENT_NAME, 'weights', 'best.pt')
if not os.path.exists(best_weight_path):
    best_weight_path = os.path.join(PROJECT_DIR, EXPERIMENT_NAME, 'weights', 'last.pt')

print(f"Loading best weights from: {best_weight_path}")
best_model = YOLO(best_weight_path)

# Run Validation on Held-out Test Split
metrics = best_model.val(data=dataset_yaml_path, split='test', imgsz=1024)

print("\\n" + "="*60)
print("OFFICIAL IDRiD TEST SPLIT — YOLO11n DETECTION METRICS")
print("="*60)
print(f"Overall mAP@0.5:      {metrics.box.map50:.4f}")
print(f"Overall mAP@0.5:0.95: {metrics.box.map:.4f}")
print(f"Mean Precision:       {metrics.box.mp:.4f}")
print(f"Mean Recall:          {metrics.box.mr:.4f}")

for idx, cls_name in enumerate(['Microaneurysm', 'Haemorrhage', 'Hard_Exudate', 'Soft_Exudate']):
    if idx < len(metrics.box.maps):
        print(f"  {cls_name:16s} - mAP@0.5: {metrics.box.maps[idx]:.4f}")
""")

    # Section 9: ONNX Export & Verification
    add_md("""## 9. ONNX Model Export
Export the trained YOLO11n detector to ONNX format.""")

    add_code("""print("Exporting trained YOLO11n model to ONNX format...")
exported_path = best_model.export(
    format='onnx',
    imgsz=1024,
    dynamic=False,
    opset=14
)

print(f"Model exported to: {exported_path}")
# Save as both yolo11n_lesions_scratch.onnx and yolo26n_lesions_scratch.onnx for full compatibility
dest_path1 = os.path.join(CHECKPOINT_DIR, 'yolo11n_lesions_scratch.onnx')
dest_path2 = os.path.join(CHECKPOINT_DIR, 'yolo26n_lesions_scratch.onnx')
shutil.copyfile(exported_path, dest_path1)
shutil.copyfile(exported_path, dest_path2)
print(f"Saved to Google Drive: {dest_path1}")
print(f"Saved alias to Google Drive: {dest_path2}")
""")

    # Section 10: MATLAB Integration Guide
    add_md("""## 10. MATLAB R2024a Integration Guide
Download `yolo11n_lesions_scratch.onnx` and copy it to:
`D:\\RetinaScan_MATLAB_SIH26038\\data\\models\\yolo11n_lesions_scratch.onnx`

### MATLAB Inference Example:
```matlab
% 1. Load ONNX Model into MATLAB R2024a
modelPath = 'D:\\RetinaScan_MATLAB_SIH26038\\data\\models\\yolo11n_lesions_scratch.onnx';
net = importNetworkFromONNX(modelPath, 'OutputDataFormats', 'BC');

% 2. Read and Preprocess 1024x1024 Retinal Image
img = imread('D:\\sih2026\\retino\\data\\samples\\idrid_samples\\idrid_grade_3.jpg');
imgResized = imresize(img, [1024, 1024]);
imgSingle = single(imgResized) / 255.0;

% Permute to NCHW format
imgTensor = permute(imgSingle, [3, 1, 2]); % [3, 1024, 1024]
dlImg = dlarray(reshape(imgTensor, [1, 3, 1024, 1024]), 'BCSS');

% 3. Run Forward Inference
predictions = predict(net, dlImg);
rawOutputs = extractdata(predictions);
fprintf('Inference completed successfully! Output dimensions: %s\\n', mat2str(size(rawOutputs)));
```""")

    # Save to BOTH file paths so either one opened by the user works!
    path1 = r"D:\RetinaScan_MATLAB_SIH26038\notebooks\train_yolo26n_lesions_from_scratch.ipynb"
    path2 = r"D:\RetinaScan_MATLAB_SIH26038\notebooks\train_yolo11n_lesions_from_scratch.ipynb"
    
    with open(path1, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2)
    with open(path2, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2)
        
    print(f"Successfully generated YOLO11n Notebook at:\n  1. {path1}\n  2. {path2}")

if __name__ == "__main__":
    create_yolo11_notebook()
