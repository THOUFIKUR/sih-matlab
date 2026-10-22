function [enhancedRGB, greenEnhanced, metadata] = enhance_retinal_image(inputImage, saveFigurePath)
% ENHANCE_RETINAL_IMAGE Performs adaptive enhancement on retinal fundus scans.
%
% Applies Contrast-Limited Adaptive Histogram Equalization (CLAHE) on the
% Luminance channel (CIE L*a*b*) and green channel. Strictly avoids per-channel
% RGB histogram equalization to prevent color distortion. Includes illumination
% normalization (background flat-field correction) and edge-preserving denoising.
%
% Includes a validated Base-MATLAB mathematical fallback if Image Processing
% Toolbox functions (rgb2lab, adapthisteq, lab2rgb) are not available.
%
% Syntax:
%   [enhancedRGB, greenEnhanced, metadata] = enhance_retinal_image(rawRGB)
%   [enhancedRGB, greenEnhanced, metadata] = enhance_retinal_image(imagePath)
%   [enhancedRGB, greenEnhanced, metadata] = enhance_retinal_image(inputImage, saveFigurePath)
%
% Outputs:
%   enhancedRGB:   Full-color enhanced fundus photograph (uint8)
%   greenEnhanced: Enhanced green channel optimized for vessel/lesion detection (uint8)
%   metadata:      Struct with method name, execution parameters, and histogram data

if nargin < 2, saveFigurePath = ''; end

if ischar(inputImage) || isstring(inputImage)
    rawRGB = imread(char(inputImage));
else
    rawRGB = inputImage;
end

if size(rawRGB, 3) == 1
    rawRGB = cat(3, rawRGB, rawRGB, rawRGB);
end

% Standardize to uint8
if isfloat(rawRGB)
    if max(rawRGB(:)) <= 1.0, rawRGB = uint8(rawRGB * 255); else, rawRGB = uint8(rawRGB); end
elseif islogical(rawRGB)
    rawRGB = uint8(rawRGB * 255);
elseif ~isa(rawRGB, 'uint8')
    rawRGB = uint8(rawRGB);
end

metadata = struct();
metadata.OriginalHistG = histcounts(rawRGB(:, :, 2), 64);

%% Try Primary Toolbox Pipeline: CIE L*a*b* CLAHE + Flat-Field
primarySucceeded = false;
try
    if (exist('rgb2lab', 'file') == 2 || exist('rgb2lab', 'builtin') == 5) && ...
       (exist('adapthisteq', 'file') == 2 || exist('adapthisteq', 'builtin') == 5)
        
        labImg = rgb2lab(rawRGB);
        L = labImg(:, :, 1); % Luminance [0, 100]

        % 1. Background Flat-Field Correction
        sigmaBg = max(round(min(size(rawRGB, 1), size(rawRGB, 2)) / 30), 15);
        if exist('imgaussfilt', 'file') == 2 || exist('imgaussfilt', 'builtin') == 5
            bgEstimate = imgaussfilt(L, sigmaBg);
        else
            bgEstimate = base_gaussfilt(L, sigmaBg);
        end
        meanL = mean(L(:));
        L_norm = L - bgEstimate + meanL;
        L_norm = max(min(L_norm, 100), 0);

        % 2. CLAHE on Normalized Luminance
        L_scaled = L_norm / 100.0;
        L_clahe = adapthisteq(L_scaled, ...
            'ClipLimit', 0.02, ...
            'NumTiles', [8 8], ...
            'Distribution', 'uniform');

        if exist('imgaussfilt', 'file') == 2 || exist('imgaussfilt', 'builtin') == 5
            L_denoised = imgaussfilt(L_clahe * 100.0, 0.5);
        else
            L_denoised = L_clahe * 100.0;
        end
        
        labEnhanced = labImg;
        labEnhanced(:, :, 1) = L_denoised;
        enhancedRGB = uint8(max(min(lab2rgb(labEnhanced) * 255, 255), 0));

        % 3. Green Channel CLAHE
        greenChannel = rawRGB(:, :, 2);
        greenClahe = adapthisteq(greenChannel, ...
            'ClipLimit', 0.02, ...
            'NumTiles', [8 8], ...
            'Distribution', 'rayleigh');
        greenEnhanced = greenClahe;

        metadata.MethodName        = 'CLAHE (CIE L*a*b* Luminance, adapthisteq) + Illumination Normalization';
        metadata.ColorSpace        = 'CIE L*a*b*';
        metadata.ClipLimit         = 0.02;
        metadata.NumTiles          = [8 8];
        metadata.IlluminationSigma = sigmaBg;
        metadata.EnhancedHistG     = histcounts(greenEnhanced, 64);
        metadata.FallbackUsed      = false;
        primarySucceeded = true;
    end
catch
    primarySucceeded = false;
end

%% Fallback Pipeline: Base-MATLAB Mathematical Contrast Enhancement & Flat-Field
if ~primarySucceeded
    [enhancedRGB, greenEnhanced, metadata] = base_matlab_enhancement(rawRGB);
end

%% Save Comparison Figure (if requested)
if ~isempty(saveFigurePath)
    try
        outDir = fileparts(saveFigurePath);
        if ~isempty(outDir) && ~exist(outDir, 'dir')
            mkdir(outDir);
        end
        
        fig = figure('Visible', 'off', 'Position', [100 100 1200 600]);
        subplot(1, 2, 1);
        imshow(rawRGB);
        title('Original Fundus Photo', 'FontSize', 12, 'FontWeight', 'bold');
        
        subplot(1, 2, 2);
        imshow(enhancedRGB);
        title(sprintf('Enhanced: %s', metadata.MethodName), 'FontSize', 11, 'FontWeight', 'bold');
        
        saveas(fig, saveFigurePath);
        delete(fig);
    catch
    end
end

end

%% =========================================================================
%% Base-MATLAB Mathematical Fallback Helpers
%% =========================================================================

function [enhancedRGB, greenEnhanced, meta] = base_matlab_enhancement(rawRGB)
% BASE_MATLAB_ENHANCEMENT Performs flat-field background correction and adaptive
% intensity contrast stretching using only native MATLAB built-in functions.

[H, W, ~] = size(rawRGB);
doubleRGB = double(rawRGB);

% 1. Estimate luminance channel: Y = 0.2989*R + 0.5870*G + 0.1140*B
Y = 0.2989 * doubleRGB(:,:,1) + 0.5870 * doubleRGB(:,:,2) + 0.1140 * doubleRGB(:,:,3);

% 2. Flat-field background illumination estimation via separable box/gaussian blur
sigmaBg = max(round(min(H, W) / 30), 15);
Y_bg = base_gaussfilt(Y, sigmaBg);
meanY = mean(Y(:));

% Illumination ratio map (avoids color shifting by scaling RGB channels proportionally)
illuminationRatio = (Y - Y_bg + meanY) ./ max(Y, 1.0);
illuminationRatio = max(min(illuminationRatio, 2.5), 0.4);

enhancedDouble = zeros(H, W, 3);
for c = 1:3
    enhancedDouble(:,:,c) = doubleRGB(:,:,c) .* illuminationRatio;
end

% 3. Robust Contrast Stretching (1st to 99th percentile) per channel
for c = 1:3
    ch = enhancedDouble(:,:,c);
    s = sort(ch(:));
    p1 = s(max(1, round(0.01 * numel(s))));
    p99 = s(min(numel(s), round(0.99 * numel(s))));
    if p99 > p1
        ch = (ch - p1) / (p99 - p1) * 255.0;
    end
    enhancedDouble(:,:,c) = ch;
end

enhancedRGB = uint8(max(min(enhancedDouble, 255), 0));

% 4. Green channel enhancement with local contrast stretch & gamma curve
G = double(rawRGB(:,:,2));
G_bg = base_gaussfilt(G, sigmaBg);
meanG = mean(G(:));
G_norm = G - G_bg + meanG;
s = sort(G_norm(:));
p1 = s(max(1, round(0.01 * numel(s))));
p99 = s(min(numel(s), round(0.99 * numel(s))));
if p99 > p1
    G_scaled = max(min((G_norm - p1) / (p99 - p1), 1.0), 0.0);
else
    G_scaled = G_norm / 255.0;
end
% Mild gamma boost to highlight fine vascular branching
G_gamma = G_scaled .^ 0.85;
greenEnhanced = uint8(G_gamma * 255.0);

meta = struct();
meta.MethodName = 'Adaptive Illumination Flat-Field + Contrast Stretch (Base-MATLAB)';
meta.ColorSpace = 'RGB Luminance Ratio';
meta.IlluminationSigma = sigmaBg;
meta.OriginalHistG = histcounts(rawRGB(:,:,2), 64);
meta.EnhancedHistG = histcounts(greenEnhanced, 64);
meta.FallbackUsed = true;
end

function out = base_gaussfilt(I, sigma)
% BASE_GAUSSFILT Native 2D Gaussian filter using separable 1D conv2.
kernelRadius = ceil(3 * sigma);
x = -kernelRadius:kernelRadius;
gKernel = exp(-(x.^2) / (2 * sigma^2));
gKernel = gKernel / sum(gKernel);

% Separable convolution with border replication
padY = kernelRadius;
padX = kernelRadius;

% Pad rows
rowPad = [repmat(I(1, :), padY, 1); I; repmat(I(end, :), padY, 1)];
colPad = [repmat(rowPad(:, 1), 1, padX), rowPad, repmat(rowPad(:, end), 1, padX)];

% Separable 1D convolutions
convRows = conv2(colPad, gKernel(:), 'valid');
out = conv2(convRows, gKernel, 'valid');
end
