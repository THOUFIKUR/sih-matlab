function [exudateCandidates, exudateMask] = segment_hard_exudates(rawRGB, odMask, retinaMask)
% SEGMENT_HARD_EXUDATES Detects hard exudate candidate lesions in color fundus images.
%
% Hard exudates appear as bright yellow/white lipid deposits with distinct, sharp
% borders. They are distinguished from the optic disc by masking out the dilated
% optic disc region.
%
% Syntax:
%   [exudateCandidates, exudateMask] = segment_hard_exudates(rawRGB)
%   [exudateCandidates, exudateMask] = segment_hard_exudates(rawRGB, odMask, retinaMask)
%
% Outputs:
%   exudateCandidates: Table of candidate findings [X, Y, Area_px, Brightness, Confidence]
%   exudateMask:       Binary mask of hard exudate candidate pixels
%
% Note: All findings are labeled strictly as "Candidate Findings", not confirmed diagnoses.

if ischar(rawRGB) || isstring(rawRGB)
    rawRGB = imread(rawRGB);
end

[imgH, imgW, ~] = size(rawRGB);

% 1. Retinal field of view mask
if nargin < 3 || isempty(retinaMask)
    gray = rgb2gray(rawRGB);
    retinaMask = gray > 15;
    retinaMask = imopen(retinaMask, strel('disk', 5));
    retinaMask = imfill(retinaMask, 'holes');
end

% 2. Optic disc localization and masking
if nargin < 2 || isempty(odMask)
    [~, ~, odMask] = detect_optic_disc(rawRGB);
end

% Dilate optic disc mask by 15 pixels to prevent bright OD margins from triggering exudates
dilatedOD = imdilate(odMask, strel('disk', 15));
validSearchMask = retinaMask & ~dilatedOD;

% 3. Color Space Transformation & High-Pass Top-Hat
% Exudates are prominent in L*a*b* Luminance (L*) and Green channel
lab = rgb2lab(rawRGB);
L = lab(:, :, 1); % 0 to 100

% Retinal background estimation via large morphological opening
seBg = strel('disk', round(min(imgH, imgW) * 0.04));
bgL = imopen(L, seBg);
diffL = L - bgL;
diffL(~validSearchMask) = 0;

% Bright candidate thresholding
validDiff = diffL(validSearchMask);
if isempty(validDiff) || max(validDiff) <= 0
    exudateCandidates = cell2table(cell(0, 5), ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Brightness', 'Confidence'});
    exudateMask = false(imgH, imgW);
    return;
end

% Candidate threshold based on background variance
meanDiff = mean(validDiff);
stdDiff  = std(validDiff);
if max(validDiff) < 8.0
    exudateCandidates = cell2table(cell(0, 5), ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Brightness', 'Confidence'});
    exudateMask = false(imgH, imgW);
    return;
end

exudateThresh = max(meanDiff + 2.5 * stdDiff, meanDiff + 8.0);
rawExudates = (diffL > exudateThresh) & validSearchMask;

% 4. Morphological cleaning & Area Filtering
% Remove single-pixel noise (< 3 pixels) and unrealistically huge artifacts
cleanedMask = bwareaopen(rawExudates, 3);
cleanedMask = imclose(cleanedMask, strel('disk', 1));

% Exclude connected components larger than 25% of FOV (likely reflection artifact)
props = regionprops(cleanedMask, 'Area', 'Centroid', 'PixelIdxList');
finalMask = false(imgH, imgW);

xCoords = [];
yCoords = [];
areas   = [];
brights = [];
confids = [];

maxAreaAllowed = 0.05 * (imgH * imgW);

for i = 1:numel(props)
    a = props(i).Area;
    if a >= 3 && a <= maxAreaAllowed
        finalMask(props(i).PixelIdxList) = true;
        c = props(i).Centroid;
        xCoords = [xCoords; c(1)]; %#ok<AGROW>
        yCoords = [yCoords; c(2)]; %#ok<AGROW>
        areas   = [areas; a]; %#ok<AGROW>
        meanBright = mean(diffL(props(i).PixelIdxList));
        brights = [brights; meanBright]; %#ok<AGROW>
        % Confidence score based on contrast above threshold
        conf = min(0.50 + 0.50 * (meanBright / (3.5 * stdDiff + eps)), 0.95);
        confids = [confids; conf]; %#ok<AGROW>
    end
end

exudateMask = finalMask;

if isempty(xCoords)
    exudateCandidates = cell2table(cell(0, 5), ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Brightness', 'Confidence'});
else
    exudateCandidates = table(xCoords, yCoords, areas, brights, confids, ...
        'VariableNames', {'X', 'Y', 'Area_px', 'Brightness', 'Confidence'});
end

end
