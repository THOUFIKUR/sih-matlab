function [foveaCenter, confidence] = localize_fovea(rawRGB, odCenter, odRadius)
% LOCALIZE_FOVEA Localizes the fovea centralis based on anatomical geometry and macular luminance.
%
% Uses the anatomical relationship to the optic disc (located approximately 2.5 optic
% disc diameters temporal to the disc) and searches for the local luminance minimum.
%
% Syntax:
%   [foveaCenter, confidence] = localize_fovea(rawRGB, odCenter, odRadius)
%
% Outputs:
%   foveaCenter: [X, Y] pixel coordinates of the fovea center
%   confidence:  Confidence score [0, 1]

if ischar(rawRGB) || isstring(rawRGB)
    rawRGB = imread(rawRGB);
end

if nargin < 2 || isempty(odCenter) || isempty(odRadius)
    [odCenter, odRadius] = detect_optic_disc(rawRGB);
end

[imgH, imgW, ~] = size(rawRGB);
green = double(rawRGB(:, :, 2));

% 1. Determine eye laterality from Optic Disc position
% Optic disc is situated nasally; fovea is situated temporally.
odd = 2 * odRadius; % One optic disc diameter in pixels
expectedDist = 2.5 * odd; % 2.5 ODD distance

if odCenter(1) < (imgW / 2)
    % Left Eye (OS): Disc is on the left, fovea is to the right (+X)
    searchDirection = +1;
else
    % Right Eye (OD): Disc is on the right, fovea is to the left (-X)
    searchDirection = -1;
end

expectedFoveaX = odCenter(1) + searchDirection * expectedDist;
expectedFoveaY = odCenter(2) + 0.15 * odd; % Anatomically slightly lower

% 2. Define Search Region of Interest (ROI) around expected location
roiRadiusX = round(1.2 * odd);
roiRadiusY = round(0.8 * odd);

xMin = max(round(expectedFoveaX - roiRadiusX), 1);
xMax = min(round(expectedFoveaX + roiRadiusX), imgW);
yMin = max(round(expectedFoveaY - roiRadiusY), 1);
yMax = min(round(expectedFoveaY + roiRadiusY), imgH);

if xMin >= xMax || yMin >= yMax
    foveaCenter = [expectedFoveaX, expectedFoveaY];
    confidence = 0.40;
    return;
end

% 3. Search for lowest intensity (macular avascular zone) in green channel
roiGreen = green(yMin:yMax, xMin:xMax);
smoothRoi = imgaussfilt(roiGreen, max(round(odRadius / 4), 3));

% Distance penalty from expected anatomical position
[roiX, roiY] = meshgrid(xMin:xMax, yMin:yMax);
distFromPrior = sqrt((roiX - expectedFoveaX).^2 + (roiY - expectedFoveaY).^2);
normDistPenalty = distFromPrior / max(distFromPrior(:));

% Cost function: minimize intensity + spatial deviation
costMap = (smoothRoi / max(smoothRoi(:))) + 0.35 * normDistPenalty;
[~, minIdx] = min(costMap(:));
[minY, minX] = ind2sub(size(costMap), minIdx);

foveaCenter = [xMin + minX - 1, yMin + minY - 1];

% Confidence based on contrast of macular minimum
localVariance = std(smoothRoi(:));
confidence = min(max(localVariance / 10.0, 0.4), 0.95);

end
