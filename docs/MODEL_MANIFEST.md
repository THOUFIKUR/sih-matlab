# RetinaScan MATLAB — Model Manifest & Verification Report

**Verification Date:** 2026-10-21  
**Project:** SIH 26038 — Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## 1. Model Inventory Summary

| Model File | Size | Framework | Verification Status | Architecture | Input Resolution | Output Format |
|---|---|---|---|---|---|---|
| `best_retinascan_model.pt` | 44.56 MB | PyTorch | **Real Binary** (Checked: PK Zip) | `timm` EfficientNet-B3 + CBAM | [1, 3, 300, 300] | Logits [1, 5] |
| `retina_model.onnx` | 44.77 MB | ONNX FP32 | **Real Binary** (Checked: ONNX Proto) | EfficientNet-B3 + CBAM + Linear | [1, 3, 300, 300] | Logits [1, 5] & Feature Map [1, 1536, H, W] |
| `yolo_lesions.onnx` | 11.75 MB | ONNX FP32 | **Real Binary** (Checked: ONNX Proto) | YOLOv8n lesion detector | [1, 3, 1024, 1024] | Bounding boxes + 3 lesion classes |
| `classifier_weights.npy` | 30.85 KB | NumPy | **Real Binary** (Checked: NUMPY) | FC weights (1536, 5) + bias (5,) | — | Float32 projection weights |
| `classifier_weights.bin` | 30.72 KB | Raw Binary | **Real Binary** | Raw bytes of linear layer weights | — | 1536 × 5 Float32 values |

> [!NOTE]
> None of the model files are Git LFS text pointers. All files contain complete binary neural network weights.

---

## 2. Deep Dive Architectural Analysis

### 2.1 `retina_model.onnx` & `best_retinascan_model.pt`
- **Origin & Code Source:** Exported via `backend/scripts/export_correct_onnx.py` from training script `backend/training/train_dr_classifier.py`.
- **Backbone:** EfficientNet-B3 feature extractor pre-trained on ImageNet.
- **Attention Module:** Convolutional Block Attention Module (CBAM) placed on the top feature representation:
  - *Channel Attention:* 1536 in-channels, reduction ratio = 16, multi-layer perceptron with Shared Conv/Linear layers.
  - *Spatial Attention:* Inter-channel max and average pooling followed by 7 × 7 convolution.
- **Classification Head:** Global Average Pooling + Dropout(p = 0.3) + Linear(1536, 5).
- **Target Classes (ICDR 5-Grade Scale):**
  - Class 0: No DR
  - Class 1: Mild Non-Proliferative DR
  - Class 2: Moderate Non-Proliferative DR
  - Class 3: Severe Non-Proliferative DR
  - Class 4: Proliferative DR
- **Dual Outputs for Explainability:**
  - `logits`: [Batch, 5] raw pre-softmax classification activations.
  - `feature_map`: [Batch, 1536, H, W] final spatial activations for computing true Grad-CAM class activation maps.

---

### 2.2 `yolo_lesions.onnx`
- **Origin:** YOLOv8 network trained on annotated fundus datasets.
- **Licence Notice:** Ultralytics YOLOv8 is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**. Incorporating or redistributing YOLOv8 derivatives imposes reciprocal copyleft obligations under AGPL-3.0.
- **Classes:**
  1. `External Bleeding / Vitreous Hemorrhage`
  2. `Exudates / Cotton Wool Spots / Retinal Scarring`
  3. `Microaneurysms / Dot-Blot Hemorrhages`
- **Input Dimension:** 1024 × 1024 RGB image, normalized to [0, 1].

---

## 3. MATLAB R2024a Compatibility & Execution Analysis

> [!NOTE]
> **TOOLBOX STATUS UPDATE:**  
> The **Deep Learning Toolbox** and **Deep Learning Toolbox Converter for ONNX Model Format** are now fully installed in MATLAB R2024a.  
> `importNetworkFromONNX`, `importONNXNetwork`, `gradCAM`, `trainnet`, `resnet50`, and `efficientnetb0` are verified available.

### Model Import Verification Plan:
1. **ONNX Import Test:** Test importing `models/retina_model.onnx` via `importNetworkFromONNX`.
2. **Numerical Alignment Check:** Compare MATLAB outputs against PyTorch/Python on identical test images (`idrid_grade_0.jpg` to `idrid_grade_4.jpg`).
3. **Contingency / Retraining Plan:** If the custom CBAM attention layer or dynamic spatial axes in `retina_model.onnx` fail native ONNX layer translation, train a native MATLAB classification network (e.g. `resnet50` or `efficientnetb0`) on APTOS using MATLAB's `trainnet`.

