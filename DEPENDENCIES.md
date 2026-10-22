# RetinaScan MATLAB — Dependencies & Environment Audit

## 1. System & Runtime Environment

- **Operating System:** Microsoft Windows 11 (win64)
- **Target Platform:** MATLAB R2024a (24.1.0.2437764), 64-bit
- **MATLAB Root Directory:** `D:\matlab 25b\matlab 24a`
- **New Project Directory:** `D:\RetinaScan_MATLAB_SIH26038`
- **Reference Repository (Read-Only):** `D:\sih2026\retino` (Git revision: `df514dc8234973656276f017ba940bc671694367`)

---

## 2. Product & Toolbox Installation Status

> [!NOTE]
> All mandatory products and deep learning support packages were successfully installed into `D:\matlab 25b\matlab 24a` using the official MathWorks Package Manager (`mpm`). Verified live via `scripts/audit_environment.m`.

| Product / Toolbox Name | License Checkout | Installed on Disk (`ver`) | Status | Role in SIH 26038 |
|---|---|---|---|---|
| **MATLAB** | OK | YES (24.1) | **INSTALLED** | Core language, graphics, and programmatic `uifigure` engine |
| **Simulink** | OK | YES (24.1) | **INSTALLED** | Base block diagram and dynamic simulation engine |
| **SimEvents** | OK | YES (24.1) | **INSTALLED** | **P0:** Discrete-event entity flow, clinic queues, and resource modeling |
| **Image Processing Toolbox** | OK | YES (24.1) | **INSTALLED** | **P1:** `adapthisteq` (CLAHE), `imfilter`, `imbinarize`, `regionprops` |
| **Computer Vision Toolbox** | OK | YES (24.1) | **INSTALLED** | **P1:** `imfindcircles` (Optic Disc), object detection utilities |
| **Deep Learning Toolbox** | OK | YES (24.1) | **INSTALLED** | **P0:** `trainnet`, `dlnetwork`, `gradCAM`, `imageLIME` |
| **Statistics & Machine Learning** | OK | YES (24.1) | **INSTALLED** | Temperature scaling calibration, ECE, statistical bootstrapping |
| **Parallel Computing Toolbox** | OK | YES (24.1) | **INSTALLED** | Multi-threaded execution and multi-node batch simulation |
| **Simscape** | OK | YES (24.1) | **INSTALLED** | Physical modeling installed |
| **Simscape Electrical** | OK | YES (24.1) | **INSTALLED** | Electrical simulation installed |

---

## 3. Support Packages Status

Installed to `C:\ProgramData\MATLAB\SupportPackages\R2024a` and verified:
1. **Deep Learning Toolbox Converter for ONNX Model Format** — Verified (`importNetworkFromONNX`, `importONNXNetwork`)
2. **Deep Learning Toolbox Model for EfficientNet-b0 Network** — Verified (`efficientnetb0`)
3. **Deep Learning Toolbox Model for ResNet-50 Network** — Verified (`resnet50`)

---

## 4. Candidate Function Verification (`which -all`)

Verified live inside MATLAB R2024a:

| Candidate Function | Expected Purpose | Found Location | Installation Status |
|---|---|---|---|
| `imread` | Image I/O | `D:\matlab 25b\matlab 24a\toolbox\matlab\imagesci\imread.m` | **FOUND** |
| `imshow` | Image display | `D:\matlab 25b\matlab 24a\toolbox\matlab\images\imshow.m` | **FOUND** |
| `imadjust` | Contrast adjustment | `D:\matlab 25b\matlab 24a\toolbox\images\images\imadjust.m` | **FOUND** |
| `adapthisteq` | Contrast-limited adaptive hist eq (CLAHE) | `D:\matlab 25b\matlab 24a\toolbox\images\images\adapthisteq.m` | **FOUND** |
| `imfilter` | Spatial filtering | `D:\matlab 25b\matlab 24a\toolbox\images\images\imfilter.m` | **FOUND** |
| `entropy` | Information entropy (quality gate) | `D:\matlab 25b\matlab 24a\toolbox\images\images\entropy.m` | **FOUND** |
| `imbinarize` | Otsu / adaptive thresholding | `D:\matlab 25b\matlab 24a\toolbox\images\images\imbinarize.m` | **FOUND** |
| `imfindcircles` | Circular Hough Transform (Optic Disc) | `D:\matlab 25b\matlab 24a\toolbox\images\images\imfindcircles.m` | **FOUND** |
| `bwlabel` | Connected components labeling | `D:\matlab 25b\matlab 24a\toolbox\images\images\bwlabel.m` | **FOUND** |
| `regionprops` | Morphological feature extraction | `D:\matlab 25b\matlab 24a\toolbox\images\images\regionprops.m` | **FOUND** |
| `trainnet` | Modern deep learning training (R2023b+) | `D:\matlab 25b\matlab 24a\toolbox\nnet\deeptrain\trainnet.m` | **FOUND** |
| `trainNetwork` | Classical deep learning training | `D:\matlab 25b\matlab 24a\toolbox\nnet\cnn\trainNetwork.m` | **FOUND** |
| `gradCAM` | Class activation mapping | `D:\matlab 25b\matlab 24a\toolbox\nnet\deepviz\core\gradCAM.m` | **FOUND** |
| `imageLIME` | LIME explainability | `D:\matlab 25b\matlab 24a\toolbox\nnet\deepviz\lime\core\imageLIME.m` | **FOUND** |
| `importNetworkFromONNX` | ONNX model importer | `D:\matlab 25b\matlab 24a\toolbox\nnet\cnn\spkgs\importNetworkFromONNX.m` | **FOUND** |
| `importONNXNetwork` | Legacy ONNX importer | `D:\matlab 25b\matlab 24a\toolbox\nnet\cnn\spkgs\importONNXNetwork.m` | **FOUND** |
| `resnet50` | Pretrained ResNet-50 weights | `D:\matlab 25b\matlab 24a\toolbox\nnet\cnn\spkgs\resnet50.m` | **FOUND** |
| `efficientnetb0` | Pretrained EfficientNet-B0 weights | `D:\matlab 25b\matlab 24a\toolbox\nnet\cnn\spkgs\efficientnetb0.m` | **FOUND** |

---

## 5. Hardware & GPU Acceleration

- **GPU Device Count:** `gpuDeviceCount` returned `0`.
- **Status:** No CUDA-compatible GPU detected on the current Windows host. Parallel Computing Toolbox is installed and will execute parallel tasks via local multi-core CPU workers (`parpool('Processes')`).
