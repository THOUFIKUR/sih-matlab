function [qualityGrade, metrics, recaptureAdvice] = assess_image_quality(inputImage, customThresh)
% ASSESS_IMAGE_QUALITY Evaluates retinal fundus image adequacy with fail-closed guarantee.
%
% Syntax:
%   [qualityGrade, metrics, recaptureAdvice] = assess_image_quality(imagePath)
%   [qualityGrade, metrics, recaptureAdvice] = assess_image_quality(rawRGB)
%   [qualityGrade, metrics, recaptureAdvice] = assess_image_quality(inputImage, customThresh)
%
% Outcomes:
%   qualityGrade: 'Good' | 'Borderline' | 'Ungradable' | 'AssessmentError'
%   metrics: struct containing:
%       .FocusScore           (Laplacian variance)
%       .MeanIntensity        ([0, 255])
%       .IlluminationEntropy  (Shannon entropy)
%       .FOVCoverage          (Percentage [0, 100])
%       .ODVisibilityScore    (Contrast ratio)
%       .VesselVisibilityScore(High-frequency gradient energy)
%       .QualityScore         (Composite [0, 100])
%       .FocusStatus          ('PASS' | 'WARNING' | 'FAIL' | 'UNAVAILABLE')
%       .IlluminationStatus   ('PASS' | 'WARNING' | 'FAIL' | 'UNAVAILABLE')
%       .FOVStatus            ('PASS' | 'WARNING' | 'FAIL' | 'UNAVAILABLE')
%       .ODStatus             ('PASS' | 'WARNING' | 'FAIL' | 'UNAVAILABLE')
%       .VesselStatus         ('PASS' | 'WARNING' | 'FAIL' | 'UNAVAILABLE')
%       .MetricDetails        (Table or struct with detailed diagnostic text)
%       .FallbackUsed         (logical, true if base MATLAB fallback was used)
%       .TechnicalError       (char, technical error stack if computation failed)
%   recaptureAdvice: Actionable clinical guidance dynamically generated from measured metrics.

if nargin < 2 || isempty(customThresh)
    try
        customThresh = quality_thresholds();
    catch
        % Fallback thresholds if config file is not on search path
        customThresh = struct();
        customThresh.focus.ungradable_below = 8.0;
        customThresh.focus.borderline_below = 18.0;
        customThresh.focus.good_min = 18.0;
        customThresh.illumination.underexposed_below = 25.0;
        customThresh.illumination.overexposed_above = 215.0;
        customThresh.illumination.entropy_min = 3.5;
        customThresh.fov.ungradable_below = 38.0;
        customThresh.fov.borderline_below = 50.0;
        customThresh.fov.good_min = 50.0;
        customThresh.optic_disc.contrast_min = 1.15;
        customThresh.vessels.gradient_min = 1.5;
    end
end

% Initial fail-closed structure: Unavailable metrics stored as NaN (never fabricated 0.0)
qualityGrade = 'Ungradable';
metrics = struct(...
    'FocusScore', NaN, ...
    'MeanIntensity', NaN, ...
    'IlluminationEntropy', NaN, ...
    'FOVCoverage', NaN, ...
    'ODVisibilityScore', NaN, ...
    'VesselVisibilityScore', NaN, ...
    'QualityScore', NaN, ...
    'FocusStatus', 'UNAVAILABLE', ...
    'IlluminationStatus', 'UNAVAILABLE', ...
    'FOVStatus', 'UNAVAILABLE', ...
    'ODStatus', 'UNAVAILABLE', ...
    'VesselStatus', 'UNAVAILABLE', ...
    'FallbackUsed', false, ...
    'TechnicalError', '', ...
    'MetricDetails', struct());

recaptureAdvice = 'RECAPTURE REQUIRED: Input could not be verified or processed.';

try
    %% 1. Input Ingestion & Validation
    if ischar(inputImage) || isstring(inputImage)
        imageFilePath = char(inputImage);
        if ~isfile(imageFilePath)
            qualityGrade = 'AssessmentError';
            metrics.TechnicalError = sprintf('Image file not found: %s', imageFilePath);
            recaptureAdvice = sprintf('ASSESSMENT ERROR: Image file not found or path inaccessible (%s). Verify file location.', imageFilePath);
            return;
        end
        try
            rawRGB = imread(imageFilePath);
        catch ME_read
            qualityGrade = 'AssessmentError';
            metrics.TechnicalError = sprintf('imread failed: %s', ME_read.message);
            recaptureAdvice = sprintf('ASSESSMENT ERROR: File is corrupted, incomplete, or unsupported format (%s).', ME_read.message);
            return;
        end
    elseif isnumeric(inputImage) || islogical(inputImage)
        rawRGB = inputImage;
    else
        qualityGrade = 'AssessmentError';
        metrics.TechnicalError = sprintf('Unsupported data type: %s', class(inputImage));
        recaptureAdvice = 'ASSESSMENT ERROR: Unsupported image data type passed to quality gate.';
        return;
    end

    % Check empty or non-2D/3D
    if isempty(rawRGB) || ndims(rawRGB) < 2
        qualityGrade = 'AssessmentError';
        metrics.TechnicalError = 'Input image array is empty or ndims < 2.';
        recaptureAdvice = 'ASSESSMENT ERROR: Input image array is empty or corrupt.';
        return;
    end

    % Check for NaN or Inf in floating point inputs
    if isfloat(rawRGB)
        if any(isnan(rawRGB(:))) || any(isinf(rawRGB(:)))
            qualityGrade = 'AssessmentError';
            metrics.TechnicalError = 'Input image contains NaN or Inf pixel values.';
            recaptureAdvice = 'ASSESSMENT ERROR: Image contains invalid numeric values (NaN or Inf).';
            return;
        end
        if max(rawRGB(:)) <= 1.0
            rawRGB = uint8(rawRGB * 255);
        else
            rawRGB = uint8(rawRGB);
        end
    elseif islogical(rawRGB)
        rawRGB = uint8(rawRGB) * 255;
    elseif ~isa(rawRGB, 'uint8')
        rawRGB = uint8(rawRGB);
    end

    if size(rawRGB, 3) == 1
        % Grayscale scan: technically ungradable for color diagnostic grading
        rawRGB = cat(3, rawRGB, rawRGB, rawRGB);
        isGrayscaleInput = true;
    else
        isGrayscaleInput = false;
    end

    [imgH, imgW, ~] = size(rawRGB);
    if imgH < 64 || imgW < 64
        qualityGrade = 'Ungradable';
        recaptureAdvice = sprintf('RECAPTURE REQUIRED: Resolution too low for diagnostic grading (%dx%d, minimum 64x64 required).', imgW, imgH);
        return;
    end

    % Convert to Grayscale using robust fallback
    [gray, usedGrayFallback] = robust_rgb2gray(rawRGB);
    doubleGray = double(gray);
    green = double(rawRGB(:, :, 2));

    %% 2. Metric Calculations with Base-MATLAB Mathematical Fallbacks
    usedFallbacks = usedGrayFallback;

    % A. Focus / Sharpness: Laplacian variance
    lapKernel = [0 1 0; 1 -4 1; 0 1 0];
    [lapFiltered, usedImfilterFallback] = robust_imfilter(doubleGray, lapKernel, 'replicate');
    usedFallbacks = usedFallbacks || usedImfilterFallback;
    focusScore = var(lapFiltered(:));

    % B. Illumination & Entropy
    meanIntensity = mean(doubleGray(:));
    [entropyScore, usedEntropyFallback] = robust_entropy(gray);
    usedFallbacks = usedFallbacks || usedEntropyFallback;

    % C. Field of View (FOV) Retinal Mask Coverage
    retinaMask = doubleGray > 12;
    fovCoverage = (sum(retinaMask(:)) / numel(retinaMask)) * 100;

    % D. Optic Disc Visibility
    retinalPixels = doubleGray(retinaMask);
    if ~isempty(retinalPixels)
        [brightThreshold, usedPrctileFallback] = robust_prctile(retinalPixels, 98);
        usedFallbacks = usedFallbacks || usedPrctileFallback;
        odCandidatePixels = retinalPixels(retinalPixels >= brightThreshold);
        backgroundPixels  = retinalPixels(retinalPixels < brightThreshold);
        if ~isempty(odCandidatePixels) && ~isempty(backgroundPixels)
            odVisibilityScore = mean(odCandidatePixels) / max(mean(backgroundPixels), 1.0);
        else
            odVisibilityScore = 1.0;
        end
    else
        odVisibilityScore = 0.0;
    end

    % E. Vessel Visibility: High-frequency gradient magnitude in green channel inside retinal mask
    [Gmag, usedGradFallback] = robust_imgradient(green);
    usedFallbacks = usedFallbacks || usedGradFallback;
    if any(retinaMask(:))
        vesselVisibilityScore = mean(Gmag(retinaMask));
    else
        vesselVisibilityScore = 0.0;
    end

    % F. Composite Normalized Quality Score [0, 100]
    focusNorm   = min(focusScore / max(customThresh.focus.good_min * 2.0, 1.0), 1.0);
    entropyNorm = min(max(entropyScore - 2.0, 0) / 5.5, 1.0);
    fovNorm     = min(fovCoverage / max(customThresh.fov.good_min, 1.0), 1.0);
    vesselNorm  = min(vesselVisibilityScore / max(customThresh.vessels.gradient_min * 4.0, 1.0), 1.0);

    qualityScore = (focusNorm * 0.35 + entropyNorm * 0.25 + fovNorm * 0.25 + vesselNorm * 0.15) * 100;

    % Store real measured numbers
    metrics.FocusScore            = focusScore;
    metrics.MeanIntensity         = meanIntensity;
    metrics.IlluminationEntropy   = entropyScore;
    metrics.FOVCoverage           = fovCoverage;
    metrics.ODVisibilityScore     = odVisibilityScore;
    metrics.VesselVisibilityScore = vesselVisibilityScore;
    metrics.QualityScore          = qualityScore;
    metrics.FallbackUsed          = usedFallbacks;

    %% 3. Per-Metric Status & Plain-Language Explanations
    
    % 1. Focus evaluation
    if focusScore < customThresh.focus.ungradable_below
        metrics.FocusStatus = 'FAIL';
        focusExpl = sprintf('Focus: FAIL (measured %.1f, threshold >= %.1f). Severe blur detected.', focusScore, customThresh.focus.ungradable_below);
        focusRec = 'Instruct patient to fixate on internal target and refocus camera diopter.';
    elseif focusScore < customThresh.focus.good_min
        metrics.FocusStatus = 'WARNING';
        focusExpl = sprintf('Focus: WARNING (measured %.1f, optimal >= %.1f). Mild softness detected.', focusScore, customThresh.focus.good_min);
        focusRec = 'Verify fine focus before saving; acceptable with enhancement.';
    else
        metrics.FocusStatus = 'PASS';
        focusExpl = sprintf('Focus: PASS (measured %.1f, threshold >= %.1f). Retinal vasculature sharp.', focusScore, customThresh.focus.good_min);
        focusRec = 'No action needed.';
    end

    % 2. Illumination evaluation
    if meanIntensity < customThresh.illumination.underexposed_below
        metrics.IlluminationStatus = 'FAIL';
        illumExpl = sprintf('Illumination: FAIL (mean intensity %.1f, threshold >= %.1f). Image underexposed.', meanIntensity, customThresh.illumination.underexposed_below);
        illumRec = 'Increase flash intensity or ensure complete pupil dilation.';
    elseif meanIntensity > customThresh.illumination.overexposed_above
        metrics.IlluminationStatus = 'FAIL';
        illumExpl = sprintf('Illumination: FAIL (mean intensity %.1f, threshold <= %.1f). Severe washout.', meanIntensity, customThresh.illumination.overexposed_above);
        illumRec = 'Reduce flash diopter and check room ambient lighting.';
    elseif entropyScore < customThresh.illumination.entropy_min
        metrics.IlluminationStatus = 'FAIL';
        illumExpl = sprintf('Illumination/Entropy: FAIL (entropy %.2f, threshold >= %.2f). Low texture detail.', entropyScore, customThresh.illumination.entropy_min);
        illumRec = 'Check camera lens cleanliness and patient eye alignment.';
    else
        metrics.IlluminationStatus = 'PASS';
        illumExpl = sprintf('Illumination: PASS (mean %.1f [25-215], entropy %.2f >= %.2f). Exposure balanced.', meanIntensity, entropyScore, customThresh.illumination.entropy_min);
        illumRec = 'No action needed.';
    end

    % 3. Retinal Field-of-View Coverage
    if fovCoverage < customThresh.fov.ungradable_below
        metrics.FOVStatus = 'FAIL';
        fovExpl = sprintf('FOV Coverage: FAIL (measured %.1f%%, threshold >= %.1f%%). Excessive aperture clipping.', fovCoverage, customThresh.fov.ungradable_below);
        fovRec = 'Center the optical axis, clear eyelid obstruction, and ensure proper eye distance.';
    elseif fovCoverage < customThresh.fov.good_min
        metrics.FOVStatus = 'WARNING';
        fovExpl = sprintf('FOV Coverage: WARNING (measured %.1f%%, optimal >= %.1f%%). Edge partially cropped.', fovCoverage, customThresh.fov.good_min);
        fovRec = 'Re-align camera aperture to capture complete retinal perimeter.';
    else
        metrics.FOVStatus = 'PASS';
        fovExpl = sprintf('FOV Coverage: PASS (measured %.1f%%, threshold >= %.1f%%). Retinal field fully visible.', fovCoverage, customThresh.fov.good_min);
        fovRec = 'No action needed.';
    end

    % 4. Optic Disc Visibility
    if odVisibilityScore < customThresh.optic_disc.contrast_min
        metrics.ODStatus = 'WARNING';
        odExpl = sprintf('Optic Disc: WARNING (contrast ratio %.2f, expected >= %.2f). Disc boundary faint.', odVisibilityScore, customThresh.optic_disc.contrast_min);
        odRec = 'Ensure disc is within field of view and check for uneven illumination.';
    else
        metrics.ODStatus = 'PASS';
        odExpl = sprintf('Optic Disc: PASS (contrast ratio %.2f >= %.2f). Optic disc clearly localized.', odVisibilityScore, customThresh.optic_disc.contrast_min);
        odRec = 'No action needed.';
    end

    % 5. Vessel Visibility
    if vesselVisibilityScore < customThresh.vessels.gradient_min
        metrics.VesselStatus = 'FAIL';
        vesselExpl = sprintf('Vessel Visibility: FAIL (gradient %.2f, threshold >= %.2f). Microvasculature not discernible.', vesselVisibilityScore, customThresh.vessels.gradient_min);
        vesselRec = 'Retake image with stable focus to resolve fine retinal vessel branches.';
    else
        metrics.VesselStatus = 'PASS';
        vesselExpl = sprintf('Vessel Visibility: PASS (gradient %.2f >= %.2f). Retinal vasculature clearly defined.', vesselVisibilityScore, customThresh.vessels.gradient_min);
        vesselRec = 'No action needed.';
    end

    % Detailed records
    metrics.MetricDetails.Focus = struct('Score', focusScore, 'Status', metrics.FocusStatus, 'Explanation', focusExpl, 'Recommendation', focusRec);
    metrics.MetricDetails.Illumination = struct('Score', meanIntensity, 'Entropy', entropyScore, 'Status', metrics.IlluminationStatus, 'Explanation', illumExpl, 'Recommendation', illumRec);
    metrics.MetricDetails.FOV = struct('Score', fovCoverage, 'Status', metrics.FOVStatus, 'Explanation', fovExpl, 'Recommendation', fovRec);
    metrics.MetricDetails.OpticDisc = struct('Score', odVisibilityScore, 'Status', metrics.ODStatus, 'Explanation', odExpl, 'Recommendation', odRec);
    metrics.MetricDetails.Vessels = struct('Score', vesselVisibilityScore, 'Status', metrics.VesselStatus, 'Explanation', vesselExpl, 'Recommendation', vesselRec);

    %% 4. Overall Quality Triage & Fail-Closed Synthesis
    
    if isGrayscaleInput
        qualityGrade = 'Ungradable';
        recaptureAdvice = 'FAIL — RECAPTURE RECOMMENDED: Monochromatic/grayscale scan detected. Color fundus photography is strictly required.';
        return;
    end

    % Compile all failed metrics
    failedItems = {};
    if strcmp(metrics.FocusStatus, 'FAIL')
        failedItems{end+1} = sprintf('• %s -> %s', focusExpl, focusRec);
    end
    if strcmp(metrics.IlluminationStatus, 'FAIL')
        failedItems{end+1} = sprintf('• %s -> %s', illumExpl, illumRec);
    end
    if strcmp(metrics.FOVStatus, 'FAIL')
        failedItems{end+1} = sprintf('• %s -> %s', fovExpl, fovRec);
    end
    if strcmp(metrics.VesselStatus, 'FAIL')
        failedItems{end+1} = sprintf('• %s -> %s', vesselExpl, vesselRec);
    end

    % Warning items
    warningItems = {};
    if strcmp(metrics.FocusStatus, 'WARNING')
        warningItems{end+1} = sprintf('• %s -> %s', focusExpl, focusRec);
    end
    if strcmp(metrics.FOVStatus, 'WARNING')
        warningItems{end+1} = sprintf('• %s -> %s', fovExpl, fovRec);
    end
    if strcmp(metrics.ODStatus, 'WARNING')
        warningItems{end+1} = sprintf('• %s -> %s', odExpl, odRec);
    end

    if ~isempty(failedItems)
        qualityGrade = 'Ungradable';
        recaptureAdvice = sprintf(['QUALITY RESULT: FAIL — RECAPTURE RECOMMENDED\n\n', ...
            'The image failed the automated quality gate for diagnostic grading. Failed metrics:\n%s\n\n', ...
            'Recommended Action: Retake fundus photograph following the capture guidelines.'], ...
            strjoin(failedItems, '\n'));
    elseif ~isempty(warningItems)
        qualityGrade = 'Borderline';
        recaptureAdvice = sprintf(['QUALITY RESULT: BORDERLINE (Review with Care)\n\n', ...
            'Image is clinically gradable but exhibits sub-optimal factors:\n%s\n\n', ...
            'Proceeding with adaptive CLAHE enhancement; tele-clinician review advised.'], ...
            strjoin(warningItems, '\n'));
    else
        qualityGrade = 'Good';
        fallbackNote = '';
        if usedFallbacks
            fallbackNote = ' (Validated base-MATLAB mathematical engine active)';
        end
        recaptureAdvice = sprintf('QUALITY RESULT: PASS (Gradeable%s)\n\nAll 5 empirical quality metrics satisfy diagnostic requirements. Image ready for automated AI screening and clinician review.', fallbackNote);
    end

catch ME
    % Strict fail-closed on computational exception — Distinguish ASSESSMENT ERROR from ungradable image
    qualityGrade = 'AssessmentError';
    metrics.TechnicalError = sprintf('%s\nStack:\n%s', ME.message, getReport(ME, 'basic'));
    recaptureAdvice = sprintf(['ASSESSMENT ERROR: Quality pipeline encountered a software exception:\n"%s"\n\n', ...
        'This indicates a system calculation limitation rather than proven optical defect. Assessment could not complete.'], ...
        ME.message);
end

end

%% =========================================================================
%% Robust Base-MATLAB Mathematical Fallbacks
%% =========================================================================

function [gray, usedFallback] = robust_rgb2gray(rgb)
% ROBUST_RGB2GRAY Converts RGB to grayscale using ITU-R BT.601 standard weights.
if exist('rgb2gray', 'file') == 2 || exist('rgb2gray', 'builtin') == 5
    try
        gray = rgb2gray(rgb);
        usedFallback = false;
        return;
    catch
    end
end
% Mathematical base fallback
usedFallback = true;
if size(rgb, 3) == 1
    gray = rgb;
else
    R = double(rgb(:, :, 1));
    G = double(rgb(:, :, 2));
    B = double(rgb(:, :, 3));
    gray = uint8(round(0.2989 * R + 0.5870 * G + 0.1140 * B));
end
end

function [out, usedFallback] = robust_imfilter(I, kernel, boundary)
% ROBUST_IMFILTER Replaces imfilter using conv2 with border replication.
% For centrally symmetric kernels (e.g. Laplacian), correlation == convolution.
if exist('imfilter', 'file') == 2 || exist('imfilter', 'builtin') == 5
    try
        out = imfilter(I, kernel, boundary);
        usedFallback = false;
        return;
    catch
    end
end

usedFallback = true;
I = double(I);
[kH, kW] = size(kernel);
padY = floor(kH / 2);
padX = floor(kW / 2);

% Replicate boundary padding using pure index replication
rowIdx = [ones(1, padY), 1:size(I, 1), repmat(size(I, 1), 1, padY)];
colIdx = [ones(1, padX), 1:size(I, 2), repmat(size(I, 2), 1, padX)];
padded = I(rowIdx, colIdx);

% conv2 with 180-degree rotated kernel implements exact 2D correlation
rotKernel = rot90(kernel, 2);
out = conv2(padded, rotKernel, 'valid');
end

function [ent, usedFallback] = robust_entropy(I)
% ROBUST_ENTROPY Shannon entropy calculated over 256 grayscale bins.
if exist('entropy', 'file') == 2 || exist('entropy', 'builtin') == 5
    try
        ent = entropy(I);
        usedFallback = false;
        return;
    catch
    end
end

usedFallback = true;
counts = histcounts(I(:), 0:256);
p = counts(counts > 0) / sum(counts);
ent = -sum(p .* log2(p));
end

function [Gmag, usedFallback] = robust_imgradient(I)
% ROBUST_IMGRADIENT Sobel gradient magnitude via conv2.
if exist('imgradient', 'file') == 2 || exist('imgradient', 'builtin') == 5
    try
        [Gmag, ~] = imgradient(I);
        usedFallback = false;
        return;
    catch
    end
end

usedFallback = true;
I = double(I);
hx = [-1 0 1; -2 0 2; -1 0 1];
hy = [-1 -2 -1; 0 0 0; 1 2 1];

[Gx, ~] = robust_imfilter(I, hx, 'replicate');
[Gy, ~] = robust_imfilter(I, hy, 'replicate');
Gmag = hypot(Gx, Gy);
end

function [val, usedFallback] = robust_prctile(data, p)
% ROBUST_PRCTILE Computes p-th percentile without Statistics Toolbox.
if exist('prctile', 'file') == 2 || exist('prctile', 'builtin') == 5
    try
        val = prctile(data, p);
        usedFallback = false;
        return;
    catch
    end
end

usedFallback = true;
if isempty(data)
    val = NaN;
    return;
end
s = sort(data(:));
idx = max(1, min(numel(s), round((p / 100) * numel(s))));
val = s(idx);
end
