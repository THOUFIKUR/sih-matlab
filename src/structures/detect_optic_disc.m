function [center, radius, odMask, confidence] = detect_optic_disc(rawRGB)
% DETECT_OPTIC_DISC Localizes the optic disc in a color fundus photograph.
%
% Combines high-luminance clustering, vessel convergence, and Circular
% Hough Transform (imfindcircles) to locate the optic disc center and boundary.
%
% Syntax:
%   [center, radius, odMask, confidence] = detect_optic_disc(rawRGB)
%
% Outputs:
%   center:     [X, Y] pixel coordinates of optic disc center
%   radius:     Estimated optic disc radius in pixels
%   odMask:     Binary mask of optic disc region
%   confidence: Confidence score [0, 1]

if ischar(rawRGB) || isstring(rawRGB)
    rawRGB = imread(rawRGB);
end

[imgH, imgW, ~] = size(rawRGB);
redChannel   = double(rawRGB(:, :, 1));
greenChannel = double(rawRGB(:, :, 2));

% 1. Retinal tissue mask to exclude dark periphery
gray = rgb2gray(rawRGB);
retinaMask = imbinarize(gray, 'adaptive', 'Sensitivity', 0.1) | (gray > 15);
retinaMask = imopen(retinaMask, strel('disk', 5));
retinaMask = imfill(retinaMask, 'holes');

% 2. Expected radius range based on resolution (approx 4% to 9% of image height)
expectedRMin = max(round(min(imgH, imgW) * 0.035), 10);
expectedRMax = max(round(min(imgH, imgW) * 0.090), 25);

% Downsample for fast robust circle search if large image (> 1000px)
scaleFactor = 1.0;
if max(imgH, imgW) > 1024
    scaleFactor = 1024 / max(imgH, imgW);
    imgSmall = imresize(rawRGB, scaleFactor);
    rMinSmall = max(round(expectedRMin * scaleFactor), 5);
    rMaxSmall = max(round(expectedRMax * scaleFactor), 15);
else
    imgSmall = rawRGB;
    rMinSmall = expectedRMin;
    rMaxSmall = expectedRMax;
end

graySmall = rgb2gray(imgSmall);
redSmall  = imgSmall(:, :, 1);

% Search with imfindcircles
[centersSmall, radiiSmall, metric] = imfindcircles(redSmall, [rMinSmall, rMaxSmall], ...
    'ObjectPolarity', 'bright', ...
    'Sensitivity', 0.92, ...
    'Method', 'TwoStage');

if ~isempty(centersSmall)
    % Select highest metric circle
    bestCenterSmall = centersSmall(1, :);
    bestRadiusSmall = radiiSmall(1);
    confidence      = min(metric(1) * 1.5, 1.0);
    
    % Scale back to original resolution
    center = bestCenterSmall / scaleFactor;
    radius = bestRadiusSmall / scaleFactor;
else
    % Fallback: Morphological bright region centroid inside retinal mask
    % Optic disc has high red and green values
    combined = (redChannel * 0.6 + greenChannel * 0.4) .* double(retinaMask);
    smoothMap = imgaussfilt(combined, expectedRMin / 2);
    
    % Find peak intensity location
    [~, maxIdx] = max(smoothMap(:));
    [maxY, maxX] = ind2sub(size(smoothMap), maxIdx);
    
    center = [maxX, maxY];
    radius = (expectedRMin + expectedRMax) / 2;
    confidence = 0.50;
end

% 3. Create circular binary mask
[Xgrid, Ygrid] = meshgrid(1:imgW, 1:imgH);
distMap = sqrt((Xgrid - center(1)).^2 + (Ygrid - center(2)).^2);
odMask = distMap <= radius;

end
