function [maCandidates, maMask] = detect_microaneurysms(rawRGB, vesselMask, odMask)
% DETECT_MICROANEURYSMS Multi-scale candidate detection with sub-pixel centroid refinement.
%
% Microaneurysms appear as isolated circular dark lesions (10-100 um) on the green channel.
% Vessels and optic disc are subtracted to minimize false positive candidate alarms.
%
% Syntax:
%   [maCandidates, maMask] = detect_microaneurysms(rawRGB)
%   [maCandidates, maMask] = detect_microaneurysms(rawRGB, vesselMask, odMask)
%
% Outputs:
%   maCandidates: Table of candidate findings [X_subpix, Y_subpix, Area_px, Contrast, Confidence]
%   maMask:       Binary mask of detected microaneurysm candidate regions
%
% Note: Labeled strictly as "Candidate Findings", not confirmed clinical diagnoses.

if ischar(rawRGB) || isstring(rawRGB)
    rawRGB = imread(rawRGB);
end

[imgH, imgW, ~] = size(rawRGB);
green = double(rawRGB(:, :, 2));

% Retinal tissue mask
gray = rgb2gray(rawRGB);
retinaMask = gray > 15;
retinaMask = imopen(retinaMask, strel('disk', 5));

if nargin < 2 || isempty(vesselMask)
    vesselMask = segment_vessels(rawRGB, retinaMask);
end

if nargin < 3 || isempty(odMask)
    [~, ~, odMask] = detect_optic_disc(rawRGB);
end

% Dilate vessel mask and optic disc mask to avoid edge false positives
dilatedVessels = imdilate(vesselMask, strel('disk', 2));
dilatedOD      = imdilate(odMask, strel('disk', 10));
searchMask     = retinaMask & ~dilatedVessels & ~dilatedOD;

%% 1. Multi-Scale Morphological Bottom-Hat Filtering
% Bottom-hat isolates dark structures smaller than structuring element
diameters = [3, 5, 7]; % Microaneurysms across resolution scales
responseMax = zeros(imgH, imgW);

for d = diameters
    se = strel('disk', d);
    bhat = imbothat(green, se);
    responseMax = max(responseMax, bhat);
end

responseMax(~searchMask) = 0;

%% 2. Candidate Extraction via Regional Maxima & Adaptive Thresholding
maxSig = max(responseMax(searchMask));
if isempty(maxSig) || maxSig < 6.0
    % Signal below sensor noise floor: no candidate microaneurysms
    maCandidates = cell2table(cell(0, 5), ...
        'VariableNames', {'X_subpix', 'Y_subpix', 'Area_px', 'Contrast', 'Confidence'});
    maMask = false(imgH, imgW);
    return;
end

normResp = responseMax / maxSig;
thresh = max(graythresh(normResp(searchMask)) * 1.25, 6.0 / maxSig);
candidateBin = (normResp >= thresh) & searchMask;

% Morphological size filtering (microaneurysms are small: 2 to 80 pixels)
candidateBin = bwareaopen(candidateBin, 2);
candidateBin = candidateBin & ~bwareaopen(candidateBin, 80);

%% 3. Sub-Pixel Centroid Refinement via Intensity-Weighted Centroid
CC = bwconncomp(candidateBin);
props = regionprops(CC, green, 'Area', 'BoundingBox', 'Eccentricity', 'PixelList', 'PixelValues');

candidates = {};
maMask = false(imgH, imgW);

for k = 1:CC.NumObjects
    p = props(k);
    % Filter out elongated non-circular structures
    if p.Eccentricity > 0.85 || p.Area < 2 || p.Area > 80
        continue;
    end
    
    pixels = p.PixelList; % [X, Y]
    % Invert green to get positive weight for dark centers
    localWeights = 255.0 - double(p.PixelValues);
    sumW = sum(localWeights);
    
    if sumW > 0
        % Sub-pixel intensity-weighted centroid
        subX = sum(pixels(:, 1) .* localWeights) / sumW;
        subY = sum(pixels(:, 2) .* localWeights) / sumW;
    else
        subX = mean(pixels(:, 1));
        subY = mean(pixels(:, 2));
    end
    
    contrastVal = mean(normResp(CC.PixelIdxList{k}));
    confidenceScore = min(max(contrastVal * 2.0 * (1.0 - p.Eccentricity), 0.1), 0.95);
    
    candidates = [candidates; {subX, subY, p.Area, contrastVal, confidenceScore}]; %#ok<AGROW>
    maMask(CC.PixelIdxList{k}) = true;
end

if isempty(candidates)
    maCandidates = cell2table(cell(0, 5), 'VariableNames', ...
        {'X_Subpixel', 'Y_Subpixel', 'Area_Pixels', 'LocalContrast', 'CandidateConfidence'});
else
    maCandidates = cell2table(candidates, 'VariableNames', ...
        {'X_Subpixel', 'Y_Subpixel', 'Area_Pixels', 'LocalContrast', 'CandidateConfidence'});
end

end
