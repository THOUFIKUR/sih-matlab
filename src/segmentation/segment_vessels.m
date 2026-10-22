function [vesselMask, vesselProb, vesselDensity] = segment_vessels(rawRGB, fovMask, threshold)
% SEGMENT_VESSELS Extracts retinal blood vessel network using multi-scale matched filtering.
%
% Applies directional 2D matched Gaussian filters to inverted green channel
% to segment the retinal vascular tree within the field-of-view aperture.
%
% Syntax:
%   [vesselMask, vesselProb, vesselDensity] = segment_vessels(rawRGB)
%   [vesselMask, vesselProb, vesselDensity] = segment_vessels(rawRGB, fovMask)
%   [vesselMask, vesselProb, vesselDensity] = segment_vessels(rawRGB, fovMask, threshold)
%
% Outputs:
%   vesselMask:    Logical binary mask of segmented retinal vessels
%   vesselProb:    Continuous vessel probability map in range [0, 1]
%   vesselDensity: Percentage of retinal area occupied by vessels

if ischar(rawRGB) || isstring(rawRGB)
    rawRGB = imread(rawRGB);
end

if nargin < 2 || isempty(fovMask)
    % Compute retinal FOV mask automatically
    gray = rgb2gray(rawRGB);
    fovMask = (gray > 15);
    fovMask = imopen(fovMask, strel('disk', 4));
    fovMask = imfill(fovMask, 'holes');
end

if nargin < 3
    threshold = []; % Adaptive threshold if empty
end

% Standardize FOV mask to logical
fovMask = logical(fovMask);
green = double(rawRGB(:, :, 2));

%% 1. Inverted Green Channel Contrast Enhancement
invGreen = 255.0 - green;
invGreenScaled = (invGreen - min(invGreen(:))) / (max(invGreen(:)) - min(invGreen(:)) + eps);

% Apply CLAHE to highlight fine vascular branching
invGreenClahe = adapthisteq(invGreenScaled, 'ClipLimit', 0.02, 'NumTiles', [8 8]);

%% 2. Multi-Directional 2D Matched Filtering
% Construct 2D Gaussian ridge filter along 12 orientations (0 to 165 deg)
kernelSize = 15;
sigma = 1.5;
L = 9; % Ridge length

[X, Y] = meshgrid(-(kernelSize-1)/2:(kernelSize-1)/2, -(kernelSize-1)/2:(kernelSize-1)/2);
angles = 0:15:165;
maxResponse = zeros(size(green));

for k = 1:numel(angles)
    theta = deg2rad(angles(k));
    % Rotate coordinate frame
    u =  X * cos(theta) + Y * sin(theta);
    v = -X * sin(theta) + Y * cos(theta);
    
    % Gaussian profile along cross-section, flat ridge along length
    kernel = exp(-0.5 * (u / sigma).^2) .* (abs(v) <= L/2);
    kernel = kernel - mean(kernel(:)); % Zero-mean filter
    
    response = imfilter(invGreenClahe, kernel, 'replicate', 'same');
    maxResponse = max(maxResponse, response);
end

% Normalize probability response inside FOV [0, 1]
maxResponse(~fovMask) = 0;
minResp = min(maxResponse(fovMask));
maxResp = max(maxResponse(fovMask));
if maxResp > minResp
    vesselProb = (maxResponse - minResp) / (maxResp - minResp);
else
    vesselProb = zeros(size(maxResponse));
end
vesselProb(~fovMask) = 0;

%% 3. Binarization & Morphological Refinement
if isempty(threshold)
    % Adaptive Otsu thresholding on vessel probability inside FOV
    probValues = vesselProb(fovMask);
    if ~isempty(probValues)
        t = graythresh(probValues) * 0.85; % Mildly sensitive threshold
    else
        t = 0.25;
    end
else
    t = threshold;
end

vesselMask = (vesselProb >= t) & fovMask;

% Remove tiny spurious noise components (< 20 pixels)
vesselMask = bwareaopen(vesselMask, 20);

% Clean isolated border artifacts
vesselMask = imerode(fovMask, strel('disk', 3)) & vesselMask;

%% 4. Vascular Density Calculation
retinalArea = sum(fovMask(:));
if retinalArea > 0
    vesselDensity = (sum(vesselMask(:)) / retinalArea) * 100.0;
else
    vesselDensity = 0.0;
end

end
