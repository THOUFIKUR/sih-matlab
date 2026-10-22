function [hemCandidates, hemMask] = classify_hemorrhages(rawRGB, vesselMask, odMask, retinaMask)
% CLASSIFY_HEMORRHAGES Detects and classifies retinal hemorrhages into dot/blot vs flame-shaped.
%
% Hemorrhages appear as dark red/brown lesions on the retina.
% - Dot/blot hemorrhages: located in deep retinal layers (INL/OPL), compact and round (Circularity >= 0.55).
% - Flame-shaped hemorrhages: located in superficial nerve fiber layer (RNFL), elongated and linear (Circularity < 0.55).
%
% Syntax:
%   [hemCandidates, hemMask] = classify_hemorrhages(rawRGB)
%   [hemCandidates, hemMask] = classify_hemorrhages(rawRGB, vesselMask, odMask, retinaMask)
%
% Outputs:
%   hemCandidates: Table of candidate findings [X, Y, Area_px, Circularity, Subtype, Confidence]
%   hemMask:       Binary mask of detected hemorrhage candidate regions
%
% Note: All findings are labeled strictly as "Candidate Findings", not confirmed diagnoses.

if ischar(rawRGB) || isstring(rawRGB)
    rawRGB = imread(rawRGB);
end

[imgH, imgW, ~] = size(rawRGB);
green = double(rawRGB(:, :, 2));

% Retinal field of view mask
if nargin < 4 || isempty(retinaMask)
    gray = rgb2gray(rawRGB);
    retinaMask = gray > 15;
    retinaMask = imopen(retinaMask, strel('disk', 5));
    retinaMask = imfill(retinaMask, 'holes');
end

% Vessel mask
if nargin < 2 || isempty(vesselMask)
    vesselMask = segment_vessels(rawRGB, retinaMask);
end

% Optic disc mask
if nargin < 3 || isempty(odMask)
    [~, ~, odMask] = detect_optic_disc(rawRGB);
end

% Dilate vessel mask and optic disc mask to avoid vessel junction false positives
dilatedVessels = imdilate(vesselMask, strel('disk', 2));
dilatedOD      = imdilate(odMask, strel('disk', 8));
validSearchMask = retinaMask & ~dilatedVessels & ~dilatedOD;

% Morphological bottom-hat filtering across multiple scales (radii 4, 8, 14 pixels)
radii = [4, 8, 14];
bhatMax = zeros(imgH, imgW);
for r = radii
    se = strel('disk', r);
    bhat = imbothat(green, se);
    bhatMax = max(bhatMax, bhat);
end

bhatMax(~validSearchMask) = 0;

validBhat = bhatMax(validSearchMask);
if isempty(validBhat) || max(validBhat) <= 0
    hemCandidates = cell2table(cell(0, 6), ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Circularity', 'Subtype', 'Confidence'});
    hemMask = false(imgH, imgW);
    return;
end

% Adaptive thresholding on dark lesion response
meanVal = mean(validBhat);
stdVal  = std(validBhat);
if max(validBhat) < 10.0
    hemCandidates = cell2table(cell(0, 6), ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Circularity', 'Subtype', 'Confidence'});
    hemMask = false(imgH, imgW);
    return;
end

thresh = max(meanVal + 2.2 * stdVal, meanVal + 10.0);
rawHems = (bhatMax > thresh) & validSearchMask;

% Filter candidate components: Area between 15 and 5000 pixels (larger than microaneurysms)
cleanedMask = bwareaopen(rawHems, 15);
props = regionprops(cleanedMask, 'Area', 'Centroid', 'Perimeter', 'Eccentricity', 'PixelIdxList');

xCoords   = [];
yCoords   = [];
areas     = [];
circs     = [];
subtypes  = {};
confids   = [];
finalMask = false(imgH, imgW);

for i = 1:numel(props)
    a = props(i).Area;
    p = props(i).Perimeter;
    if a >= 15 && a <= 5000 && p > 0
        % Circularity = 4 * pi * Area / Perimeter^2
        c = (4 * pi * a) / (p^2);
        c = min(c, 1.0); % Cap at 1.0
        
        centroid = props(i).Centroid;
        xCoords = [xCoords; centroid(1)]; %#ok<AGROW>
        yCoords = [yCoords; centroid(2)]; %#ok<AGROW>
        areas   = [areas; a];             %#ok<AGROW>
        circs   = [circs; c];             %#ok<AGROW>
        
        if c >= 0.55
            subtypes = [subtypes; {'Dot/Blot'}]; %#ok<AGROW>
        else
            subtypes = [subtypes; {'Flame-shaped'}]; %#ok<AGROW>
        end
        
        % Confidence score based on contrast and morphology
        conf = min(0.55 + 0.35 * (mean(bhatMax(props(i).PixelIdxList)) / (3.0 * stdVal + eps)), 0.95);
        confids = [confids; conf]; %#ok<AGROW>
        
        finalMask(props(i).PixelIdxList) = true;
    end
end

hemMask = finalMask;

if isempty(xCoords)
    hemCandidates = cell2table(cell(0, 6), ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Circularity', 'Subtype', 'Confidence'});
else
    hemCandidates = table(xCoords, yCoords, areas, circs, subtypes, confids, ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Circularity', 'Subtype', 'Confidence'});
end

end
