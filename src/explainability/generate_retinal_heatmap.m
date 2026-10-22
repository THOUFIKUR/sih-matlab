function [heatmapOverlay, rawHeatmap] = generate_retinal_heatmap(rawImg, detectionsTable)
% GENERATE_RETINAL_HEATMAP Generates clinical attention / Class Activation Heatmap
% for explainable diabetic retinopathy decision support.
%
% Generates a thermal attention map highlighting regions with microvascular
% lesions (microaneurysms, hemorrhages, exudates) and abnormal retinal texture.
%
% Output:
%   heatmapOverlay: RGB image blended with original fundus photograph (uint8)
%   rawHeatmap:     Normalized 2D floating-point attention intensity [0, 1]

if ischar(rawImg) || isstring(rawImg)
    rawImg = imread(rawImg);
end

[imgH, imgW, numCh] = size(rawImg);
if numCh == 1
    rawImg = repmat(rawImg, [1, 1, 3]);
end

% 1. Extract Green channel for hemoglobin / vessel contrast
greenCh = double(rawImg(:, :, 2));

% 2. Retinal FOV circular mask
gray = double(rgb2gray_native(rawImg));
fovMask = gray > 20;

% 3. Calculate spatial gradient energy (microvascular texture)
gx = [-1 0 1; -2 0 2; -1 0 1];
gy = gx';
gradX = conv2(greenCh, gx, 'same');
gradY = conv2(greenCh, gy, 'same');
gradMag = sqrt(gradX.^2 + gradY.^2) .* fovMask;

% Smooth gradient energy with Gaussian kernel
hSize = max(15, round(min(imgH, imgW) / 40));
if mod(hSize, 2) == 0, hSize = hSize + 1; end
sigma = hSize / 3.0;
[X, Y] = meshgrid(-floor(hSize/2):floor(hSize/2));
gKernel = exp(-(X.^2 + Y.^2) / (2 * sigma^2));
gKernel = gKernel / sum(gKernel(:));

smoothGrad = conv2(gradMag, gKernel, 'same');

% 4. Add lesion candidate attention peaks if detections exist
lesionDensity = zeros(imgH, imgW);
if nargin >= 2 && istable(detectionsTable) && height(detectionsTable) > 0
    kRadius = max(25, round(min(imgH, imgW) / 25));
    if mod(kRadius, 2) == 0, kRadius = kRadius + 1; end
    kSigma = kRadius / 2.5;
    [kx, ky] = meshgrid(-floor(kRadius/2):floor(kRadius/2));
    peakKernel = exp(-(kx.^2 + ky.^2) / (2 * kSigma^2));
    
    for i = 1:height(detectionsTable)
        cx = round((detectionsTable.X1(i) + detectionsTable.X2(i)) / 2);
        cy = round((detectionsTable.Y1(i) + detectionsTable.Y2(i)) / 2);
        conf = detectionsTable.Confidence(i);
        
        rx1 = max(1, cx - floor(kRadius/2));
        rx2 = min(imgW, cx + floor(kRadius/2));
        ry1 = max(1, cy - floor(kRadius/2));
        ry2 = min(imgH, cy + floor(kRadius/2));
        
        kx1 = 1 + (rx1 - (cx - floor(kRadius/2)));
        kx2 = kRadius - ((cx + floor(kRadius/2)) - rx2);
        ky1 = 1 + (ry1 - (cy - floor(kRadius/2)));
        ky2 = kRadius - ((cy + floor(kRadius/2)) - ry2);
        
        lesionDensity(ry1:ry2, rx1:rx2) = lesionDensity(ry1:ry2, rx1:rx2) + ...
            conf * peakKernel(ky1:ky2, kx1:kx2);
    end
end

% 5. Combine texture gradient attention and lesion detection density
combined = (smoothGrad / (max(smoothGrad(:)) + 1e-6)) * 0.35 + ...
           (lesionDensity / (max(lesionDensity(:)) + 1e-6)) * 0.65;
combined = combined .* fovMask;

% Percentile normalization for high visual contrast
validVals = combined(fovMask);
if ~isempty(validVals)
    pLow = prctile_native(validVals, 5);
    pHigh = prctile_native(validVals, 98);
    normMap = (combined - pLow) / (pHigh - pLow + 1e-6);
    normMap = max(0, min(1, normMap)) .* fovMask;
else
    normMap = combined;
end

rawHeatmap = normMap;

% 6. Map to Vibrant Thermal Colormap (Deep Indigo -> Turquoise -> Yellow -> Radiant Red)
thermalMap = turbo_colormap(normMap);

% 7. True Clinical Heatmap Blend (Vibrant Thermal Attention)
% Inside retinal FOV: Alpha blend with original fundus; outside FOV: Keep black background
alpha = 0.55;
heatmapOverlay = rawImg;
for c = 1:3
    chRaw = double(rawImg(:, :, c));
    chTherm = double(thermalMap(:, :, c));
    % Dynamic alpha: stronger color intensity over high-attention areas
    dynamicAlpha = alpha * (0.4 + 0.6 * normMap);
    blended = chRaw .* (1 - dynamicAlpha) + chTherm .* dynamicAlpha;
    blended(~fovMask) = 0; % Keep dark fundus margin
    heatmapOverlay(:, :, c) = uint8(max(0, min(255, round(blended))));
end

end

%% Native Helpers (Base MATLAB)
function gray = rgb2gray_native(img)
    gray = 0.2989 * double(img(:, :, 1)) + ...
           0.5870 * double(img(:, :, 2)) + ...
           0.1140 * double(img(:, :, 3));
end

function p = prctile_native(v, pct)
    v = sort(v(:));
    N = numel(v);
    if N == 0, p = 0; return; end
    k = max(1, min(N, round((pct / 100) * (N - 1) + 1)));
    p = v(k);
end

function rgb = turbo_colormap(grayNorm)
    % Vibrant Grad-CAM thermal mapping: Deep Violet/Blue -> Cyan/Green -> Yellow -> Deep Red
    [H, W] = size(grayNorm);
    rgb = zeros(H, W, 3, 'uint8');
    
    % Piecewise smooth polynomial approximation of Turbo/Inferno
    x = grayNorm;
    r = clamp_val(0.1357 + x .* (4.5974 - x .* (42.3277 - x .* (130.5887 - x .* (150.5667 - x * 58.1375)))));
    g = clamp_val(0.0914 + x .* (2.1856 + x .* (4.8052 - x .* (14.0195 + x .* (4.2109 + x * 2.7747)))));
    b = clamp_val(0.1067 + x .* (12.5833 - x .* (78.4355 - x .* (178.6814 - x .* (174.5205 - x * 62.0624)))));
    
    rgb(:, :, 1) = uint8(r * 255);
    rgb(:, :, 2) = uint8(g * 255);
    rgb(:, :, 3) = uint8(b * 255);
end

function rgb = jet_colormap(grayNorm)
    % Standard 3-channel Jet color mapping [0, 1] -> [0, 255]
    [H, W] = size(grayNorm);
    rgb = zeros(H, W, 3, 'uint8');
    
    r = clamp_val(1.5 - abs(grayNorm * 4 - 3));
    g = clamp_val(1.5 - abs(grayNorm * 4 - 2));
    b = clamp_val(1.5 - abs(grayNorm * 4 - 1));
    
    rgb(:, :, 1) = uint8(r * 255);
    rgb(:, :, 2) = uint8(g * 255);
    rgb(:, :, 3) = uint8(b * 255);
end

function out = clamp_val(v)
    out = max(0, min(1, v));
end
