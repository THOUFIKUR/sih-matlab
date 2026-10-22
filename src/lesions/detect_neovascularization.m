function [nvReport, nvMask] = detect_neovascularization(rawRGB, vesselMask, odCenter, odRadius, retinaMask)
% DETECT_NEOVASCULARIZATION Detects candidate neovascularization networks with explicit uncertainty.
%
% Neovascularization represents fragile, abnormal, highly tortuous new vessel fronds:
% - Neovascularization of the Disc (NVD): within 1 optic disc diameter of the disc boundary.
% - Neovascularization Elsewhere (NVE): outside 1 disc diameter.
%
% Syntax:
%   [nvReport, nvMask] = detect_neovascularization(rawRGB)
%   [nvReport, nvMask] = detect_neovascularization(rawRGB, vesselMask, odCenter, odRadius, retinaMask)
%
% Outputs:
%   nvReport: Struct containing:
%       - hasNVCandidate:  logical flag (true if abnormal vessel frond detected)
%       - nvdCandidate:    logical flag (NVD detected near disc)
%       - nveCandidate:    logical flag (NVE detected in periphery)
%       - uncertaintyLevel: 'Low', 'Moderate', or 'High'
%       - confidenceScore: [0, 1] numerical confidence
%       - explanation:     Detailed text explanation of anatomical/morphological indicators
%       - candidateFindings: Table of detected candidate vessel clusters
%   nvMask:   Binary mask of candidate neovascularization clusters
%
% Note: Labeled strictly as "Candidate Findings", NOT a clinical diagnosis.

if ischar(rawRGB) || isstring(rawRGB)
    rawRGB = imread(rawRGB);
end

[imgH, imgW, ~] = size(rawRGB);

% Retinal field of view mask
if nargin < 5 || isempty(retinaMask)
    gray = rgb2gray(rawRGB);
    retinaMask = gray > 15;
    retinaMask = imopen(retinaMask, strel('disk', 5));
    retinaMask = imfill(retinaMask, 'holes');
end

% Optic disc localization
if nargin < 4 || isempty(odCenter) || isempty(odRadius)
    [odCenter, odRadius] = detect_optic_disc(rawRGB);
end

% Vessel mask
if nargin < 2 || isempty(vesselMask)
    vesselMask = segment_vessels(rawRGB, retinaMask);
end

% Skeletonize vessels to analyze branching and tortuosity
vesselSkel = bwskel(vesselMask);

% Branch points in vessel skeleton
branchPoints = bwmorph(vesselSkel, 'branchpoints');

% 1. Optical Disc Proximity Mask (for NVD vs NVE)
% 1 Disc Diameter (ODD) = 2 * odRadius
odd = 2 * odRadius;
[Xgrid, Ygrid] = meshgrid(1:imgW, 1:imgH);
distFromODCenter = hypot(Xgrid - odCenter(1), Ygrid - odCenter(2));
odMarginDist = distFromODCenter - odRadius;

% NVD zone: within 1 ODD from optic disc boundary
nvdZone = (odMarginDist <= odd) & (odMarginDist >= 0);

% 2. Local Branching Density Map
% Convolve branch points with Gaussian filter
densityKernel = fspecial('gaussian', round(odd), round(odd / 4));
branchDensity = imfilter(double(branchPoints), densityKernel, 'replicate');
branchDensity(~retinaMask) = 0;

% 3. Fine Looping Vessel Cluster Detection
% Thin vessel fragments outside the main vascular trunk with high curvature
endpoints = bwmorph(vesselSkel, 'endpoints');
vesselSegments = vesselSkel & ~branchPoints;

% Connected components of vessel segments
segCC = bwconncomp(vesselSegments);
segProps = regionprops(segCC, 'Area', 'Eccentricity', 'MajorAxisLength', 'PixelIdxList', 'Centroid');

candidatePixels = false(imgH, imgW);
clusterX = [];
clusterY = [];
clusterType = {};
clusterTort = [];
clusterScore = [];

for i = 1:segCC.NumObjects
    a = segProps(i).Area;
    ecc = segProps(i).Eccentricity;
    majorLen = segProps(i).MajorAxisLength;
    
    % Neovascular fronds typically consist of clustered short segments (< 0.5 ODD)
    % with high tortuosity (lower majorAxis/area ratio compared to straight trunks)
    if a >= 10 && a <= (0.8 * odd) && majorLen > 0
        tortRatio = a / majorLen; % Higher ratio indicates coiled/tortuous morphology
        if tortRatio > 1.35 && ecc < 0.96
            c = segProps(i).Centroid;
            distToOD = hypot(c(1) - odCenter(1), c(2) - odCenter(2)) - odRadius;
            
            % Check local branch density around segment
            localDensity = branchDensity(round(c(2)), round(c(1)));
            
            if localDensity > 0.005 || tortRatio > 1.8
                candidatePixels(segProps(i).PixelIdxList) = true;
                clusterX = [clusterX; c(1)]; %#ok<AGROW>
                clusterY = [clusterY; c(2)]; %#ok<AGROW>
                clusterTort = [clusterTort; tortRatio]; %#ok<AGROW>
                
                if distToOD <= odd
                    clusterType = [clusterType; {'NVD Candidate'}]; %#ok<AGROW>
                else
                    clusterType = [clusterType; {'NVE Candidate'}]; %#ok<AGROW>
                end
                
                score = min(0.40 + 0.30 * tortRatio + 20 * localDensity, 0.95);
                clusterScore = [clusterScore; score]; %#ok<AGROW>
            end
        end
    end
end

% Aggregate clusters into final mask
nvMask = imdilate(candidatePixels, strel('disk', 2)) & retinaMask;

hasNVCandidate = ~isempty(clusterX);
nvdCandidate = any(strcmp(clusterType, 'NVD Candidate'));
nveCandidate = any(strcmp(clusterType, 'NVE Candidate'));

% Determine uncertainty level based on evidence strength
if ~hasNVCandidate
    uncertaintyLevel = 'Low';
    confidenceScore = 0.90; % Confident in absence
    explanation = 'No suspicious abnormal tortuous vessel fronds or branching clusters detected.';
    findingsTable = cell2table(cell(0, 5), ...
        'VariableNames', {'X', 'Y', 'Type', 'TortuosityIndex', 'Confidence'});
else
    findingsTable = table(clusterX, clusterY, clusterType, clusterTort, clusterScore, ...
        'VariableNames', {'X', 'Y', 'Type', 'TortuosityIndex', 'Confidence'});
    
    maxConf = max(clusterScore);
    numClusters = numel(clusterX);
    
    if numClusters >= 3 && maxConf >= 0.75
        uncertaintyLevel = 'Moderate';
        confidenceScore = maxConf;
        explanation = sprintf('Multiple (%d) candidate neovascular loops identified with high tortuosity. Clinician confirmation required to differentiate from collaterals.', numClusters);
    else
        % Few or subtle fronds have intrinsically high clinical uncertainty on fundus photography
        uncertaintyLevel = 'High';
        confidenceScore = maxConf;
        explanation = sprintf('Subtle candidate vessel irregularity detected (%d cluster). High clinical uncertainty; requires clinical evaluation (OCT-A / Fluorescein Angiography recommended).', numClusters);
    end
end

nvReport = struct();
nvReport.hasNVCandidate = hasNVCandidate;
nvReport.nvdCandidate = nvdCandidate;
nvReport.nveCandidate = nveCandidate;
nvReport.uncertaintyLevel = uncertaintyLevel;
nvReport.confidenceScore = confidenceScore;
nvReport.explanation = explanation;
nvReport.candidateFindings = findingsTable;

end
