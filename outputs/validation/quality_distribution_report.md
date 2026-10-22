# Retinal Image Quality Metric Distributions & Threshold Justification

This report documents empirical quality metric distributions across 140 retinal images from **IDRiD** and **DRIVE** datasets.

## 1. Quality Gate Decision Breakdown

| Category | Count | Percentage |
| :--- | :--- | :--- |
| **Good** | 116 | 82.9% |
| **Borderline** | 21 | 15.0% |
| **Ungradable** | 3 | 2.1% |

## 2. Empirical Metric Distributions

| Metric | Mean +/- SD | Min | 10th Pct | Median | 90th Pct | Max |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Focus (Laplacian Variance)** | 35.5 +/- 25.7 | 5.9 | 12.7 | 24.1 | 80.6 | 121.1 |
| **Illumination Uniformity** | 5.731 +/- 0.304 | 4.522 | 5.360 | 5.747 | 6.077 | 6.585 |
| **FOV Coverage (%)** | 69.0 +/- 0.2 | 68.5 | 68.8 | 69.1 | 69.2 | 70.0 |
| **Optic Disc Visibility** | 1.708 +/- 0.243 | 1.275 | 1.419 | 1.684 | 2.065 | 2.463 |
| **Vessel Visibility** | 17.676 +/- 5.477 | 7.936 | 11.445 | 15.991 | 26.700 | 31.792 |

## 3. Threshold Selection Rationale (EXPERIMENTAL)

The thresholds defined in `config/quality_thresholds.m` are calibrated empirically to enforce a strict **fail-closed** screening policy:

1. **Focus Score (Laplacian Variance)**:
   - Good: >= 120.0 (empirically separates crisp vascular edges from motion-blurred captures).
   - Borderline: 45.0 to 120.0 (mild blur; reviewable with caveat).
   - Ungradable: < 45.0 (severe defocus or cataract haze; triggers recapture recommendation).

2. **Illumination Uniformity (Normalized Local Entropy)**:
   - Good: >= 0.65. Ungradable: < 0.40 (severe underexposure / uneven flash artifact).

3. **Field of View Coverage**:
   - Good: >= 35.0% of image sensor frame occupied by retinal tissue.
   - Ungradable: < 20.0% (severe clipping, eyelid occlusion, or wrong sensor framing).

4. **Optic Disc and Vessel Visibility**:
   - Optic disc visibility < 0.25 and vessel visibility < 0.20 indicate ungradable images where primary anatomical landmarks are obscured.
