function summary = evaluate_quality_distributions(maxSamples)
% EVALUATE_QUALITY_DISTRIBUTIONS Reports empirical metric distributions across IDRiD & DRIVE.
%
% Runs assess_image_quality across IDRiD and DRIVE datasets to establish
% empirical distributions for focus, illumination, FOV coverage, OD visibility,
% and vessel visibility, explaining the experimental threshold selection.
%
% Syntax:
%   summary = evaluate_quality_distributions()
%   summary = evaluate_quality_distributions(maxSamples)

if nargin < 1 || isempty(maxSamples)
    maxSamples = 100; % Representative subset for distribution profiling
end

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

outputDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'outputs', 'validation');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

fprintf('=== EVALUATING IMAGE QUALITY METRICS DISTRIBUTIONS ===\n');

% Load IDRiD Grading paths
idridTable = load_idrid_grading();
driveTable = load_drive();

numIDRiD = min(height(idridTable), maxSamples);
numDRIVE = min(height(driveTable), 40);

allRows = cell(numIDRiD + numDRIVE, 9);
idx = 0;

fprintf('Processing %d IDRiD images...\n', numIDRiD);
for i = 1:numIDRiD
    imgPath = idridTable.ImagePath{i};
    if ~isfile(imgPath), continue; end
    img = imread(imgPath);
    
    [decision, metrics, msg] = assess_image_quality(img);
    idx = idx + 1;
    allRows{idx, 1} = 'IDRiD';
    allRows{idx, 2} = idridTable.ImageName{i};
    allRows{idx, 3} = metrics.FocusScore;
    allRows{idx, 4} = metrics.IlluminationEntropy;
    allRows{idx, 5} = metrics.FOVCoverage;
    allRows{idx, 6} = metrics.ODVisibilityScore;
    allRows{idx, 7} = metrics.VesselVisibilityScore;
    allRows{idx, 8} = decision;
    allRows{idx, 9} = msg;
end

fprintf('Processing %d DRIVE images...\n', numDRIVE);
for i = 1:numDRIVE
    imgPath = driveTable.ImagePath{i};
    if ~isfile(imgPath), continue; end
    img = imread(imgPath);
    
    [decision, metrics, msg] = assess_image_quality(img);
    idx = idx + 1;
    allRows{idx, 1} = 'DRIVE';
    allRows{idx, 2} = driveTable.ImageName{i};
    allRows{idx, 3} = metrics.FocusScore;
    allRows{idx, 4} = metrics.IlluminationEntropy;
    allRows{idx, 5} = metrics.FOVCoverage;
    allRows{idx, 6} = metrics.ODVisibilityScore;
    allRows{idx, 7} = metrics.VesselVisibilityScore;
    allRows{idx, 8} = decision;
    allRows{idx, 9} = msg;
end

metricTable = cell2table(allRows(1:idx, :), 'VariableNames', ...
    {'Dataset', 'ImageName', 'FocusScore', 'IllumUniformity', 'FOVCoverage', ...
     'ODVisibility', 'VesselVisibility', 'Decision', 'RecaptureMessage'});

csvPath = fullfile(outputDir, 'quality_metrics_summary.csv');
writetable(metricTable, csvPath);
fprintf('Saved per-image quality metrics to: %s\n', csvPath);

% Distribution statistics
focusVals = metricTable.FocusScore;
illumVals = metricTable.IllumUniformity;
fovVals   = metricTable.FOVCoverage;
odVals    = metricTable.ODVisibility;
vessVals  = metricTable.VesselVisibility;

summary = struct();
summary.totalImages = idx;
summary.goodCount = sum(strcmp(metricTable.Decision, 'Good'));
summary.borderlineCount = sum(strcmp(metricTable.Decision, 'Borderline'));
summary.ungradableCount = sum(strcmp(metricTable.Decision, 'Ungradable'));

% Write detailed markdown report
mdPath = fullfile(outputDir, 'quality_distribution_report.md');
fid = fopen(mdPath, 'w');
fprintf(fid, '# Retinal Image Quality Metric Distributions & Threshold Justification\n\n');
fprintf(fid, 'This report documents empirical quality metric distributions across %d retinal images from **IDRiD** and **DRIVE** datasets.\n\n', idx);
fprintf(fid, '## 1. Quality Gate Decision Breakdown\n\n');
fprintf(fid, '| Category | Count | Percentage |\n');
fprintf(fid, '| :--- | :--- | :--- |\n');
fprintf(fid, '| **Good** | %d | %.1f%% |\n', summary.goodCount, 100 * summary.goodCount / idx);
fprintf(fid, '| **Borderline** | %d | %.1f%% |\n', summary.borderlineCount, 100 * summary.borderlineCount / idx);
fprintf(fid, '| **Ungradable** | %d | %.1f%% |\n\n', summary.ungradableCount, 100 * summary.ungradableCount / idx);

fprintf(fid, '## 2. Empirical Metric Distributions\n\n');
fprintf(fid, '| Metric | Mean +/- SD | Min | 10th Pct | Median | 90th Pct | Max |\n');
fprintf(fid, '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n');
fprintf(fid, '| **Focus (Laplacian Variance)** | %.1f +/- %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n', ...
    mean(focusVals), std(focusVals), min(focusVals), prctile(focusVals, 10), median(focusVals), prctile(focusVals, 90), max(focusVals));
fprintf(fid, '| **Illumination Uniformity** | %.3f +/- %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
    mean(illumVals), std(illumVals), min(illumVals), prctile(illumVals, 10), median(illumVals), prctile(illumVals, 90), max(illumVals));
fprintf(fid, '| **FOV Coverage (%%)** | %.1f +/- %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n', ...
    mean(fovVals), std(fovVals), min(fovVals), prctile(fovVals, 10), median(fovVals), prctile(fovVals, 90), max(fovVals));
fprintf(fid, '| **Optic Disc Visibility** | %.3f +/- %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
    mean(odVals), std(odVals), min(odVals), prctile(odVals, 10), median(odVals), prctile(odVals, 90), max(odVals));
fprintf(fid, '| **Vessel Visibility** | %.3f +/- %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n\n', ...
    mean(vessVals), std(vessVals), min(vessVals), prctile(vessVals, 10), median(vessVals), prctile(vessVals, 90), max(vessVals));

fprintf(fid, '## 3. Threshold Selection Rationale (EXPERIMENTAL)\n\n');
fprintf(fid, 'The thresholds defined in `config/quality_thresholds.m` are calibrated empirically to enforce a strict **fail-closed** screening policy:\n\n');
fprintf(fid, '1. **Focus Score (Laplacian Variance)**:\n');
fprintf(fid, '   - Good: >= 120.0 (empirically separates crisp vascular edges from motion-blurred captures).\n');
fprintf(fid, '   - Borderline: 45.0 to 120.0 (mild blur; reviewable with caveat).\n');
fprintf(fid, '   - Ungradable: < 45.0 (severe defocus or cataract haze; triggers recapture recommendation).\n\n');
fprintf(fid, '2. **Illumination Uniformity (Normalized Local Entropy)**:\n');
fprintf(fid, '   - Good: >= 0.65. Ungradable: < 0.40 (severe underexposure / uneven flash artifact).\n\n');
fprintf(fid, '3. **Field of View Coverage**:\n');
fprintf(fid, '   - Good: >= 35.0%% of image sensor frame occupied by retinal tissue.\n');
fprintf(fid, '   - Ungradable: < 20.0%% (severe clipping, eyelid occlusion, or wrong sensor framing).\n\n');
fprintf(fid, '4. **Optic Disc and Vessel Visibility**:\n');
fprintf(fid, '   - Optic disc visibility < 0.25 and vessel visibility < 0.20 indicate ungradable images where primary anatomical landmarks are obscured.\n');
fclose(fid);

fprintf('\nQuality distribution report saved to: %s\n', mdPath);

end
