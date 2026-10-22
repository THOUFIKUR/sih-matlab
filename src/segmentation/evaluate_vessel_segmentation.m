function summaryStats = evaluate_vessel_segmentation(maxImages)
% EVALUATE_VESSEL_SEGMENTATION Evaluates vessel segmentation on DRIVE dataset.
%
% Evaluates segmentation performance against 1st observer manual ground truth
% strictly within the official field-of-view (FOV) aperture mask.
%
% Syntax:
%   summaryStats = evaluate_vessel_segmentation()
%   summaryStats = evaluate_vessel_segmentation(maxImages)
%
% Outputs:
%   summaryStats: Struct containing mean Dice, Sensitivity, Specificity, Accuracy, and AUC.

if nargin < 1 || isempty(maxImages)
    maxImages = Inf;
end

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

outputDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'outputs', 'validation');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

fprintf('=== EVALUATING VESSEL SEGMENTATION (DRIVE Dataset) ===\n');

driveTable = load_drive('Train'); % 20 training images with 1st_manual annotations
numImages = min(height(driveTable), maxImages);
fprintf('Total images to evaluate: %d (Split: DRIVE 1st-Manual Training Set)\n', numImages);

results = cell(numImages, 7);

dices   = [];
sens    = [];
specs   = [];
accs    = [];
aucs    = [];

for i = 1:numImages
    imgPath  = driveTable.ImagePath{i};
    maskPath = driveTable.MaskPath{i};
    manPath  = driveTable.ManualPath{i};
    idStr    = driveTable.ImageName{i};
    
    if ~isfile(imgPath) || ~isfile(maskPath) || ~isfile(manPath)
        warning('Missing file for image %s', idStr);
        continue;
    end
    
    img = imread(imgPath);
    fovMask = logical(imread(maskPath));
    gtVessels = logical(imread(manPath));
    
    % Run vessel segmentation
    [predVessels, vesselProb, ~] = segment_vessels(img, fovMask);
    
    % Evaluate strictly inside FOV mask
    predInFOV = predVessels(fovMask);
    gtInFOV   = gtVessels(fovMask);
    probInFOV = vesselProb(fovMask);
    
    TP = sum(predInFOV & gtInFOV);
    FP = sum(predInFOV & ~gtInFOV);
    TN = sum(~predInFOV & ~gtInFOV);
    FN = sum(~predInFOV & gtInFOV);
    
    sensitivity = TP / (TP + FN + eps);
    specificity = TN / (TN + FP + eps);
    accuracy    = (TP + TN) / (TP + TN + FP + FN + eps);
    diceCoeff   = (2 * TP) / (2 * TP + FP + FN + eps);
    
    % Compute AUC using perfcurve
    try
        [~, ~, ~, aucVal] = perfcurve(double(gtInFOV), double(probInFOV), 1);
    catch
        aucVal = NaN;
    end
    
    dices = [dices; diceCoeff];   %#ok<AGROW>
    sens  = [sens; sensitivity];   %#ok<AGROW>
    specs = [specs; specificity]; %#ok<AGROW>
    accs  = [accs; accuracy];     %#ok<AGROW>
    aucs  = [aucs; aucVal];       %#ok<AGROW>
    
    results{i, 1} = idStr;
    results{i, 2} = diceCoeff;
    results{i, 3} = sensitivity;
    results{i, 4} = specificity;
    results{i, 5} = accuracy;
    results{i, 6} = aucVal;
    results{i, 7} = sum(predInFOV) / sum(fovMask(:)); % Vessel density in FOV
    
    fprintf('  [%d/%d] Image %s: Dice=%.4f, Sens=%.4f, Spec=%.4f, Acc=%.4f, AUC=%.4f\n', ...
        i, numImages, idStr, diceCoeff, sensitivity, specificity, accuracy, aucVal);
end

% Save Per-Image CSV
resTable = cell2table(results(1:numImages, :), 'VariableNames', ...
    {'ImageID', 'Dice', 'Sensitivity', 'Specificity', 'Accuracy', 'AUC', 'VesselDensity'});

csvPath = fullfile(outputDir, 'vessel_segmentation_metrics.csv');
writetable(resTable, csvPath);
fprintf('Saved per-image vessel metrics to: %s\n', csvPath);

% Summary stats
summaryStats = struct();
summaryStats.numEvaluated = numImages;
summaryStats.meanDice = mean(dices);
summaryStats.stdDice  = std(dices);
summaryStats.meanSensitivity = mean(sens);
summaryStats.stdSensitivity  = std(sens);
summaryStats.meanSpecificity = mean(specs);
summaryStats.stdSpecificity  = std(specs);
summaryStats.meanAccuracy    = mean(accs);
summaryStats.stdAccuracy     = std(accs);

validAucs = aucs(~isnan(aucs));
summaryStats.meanAUC = mean(validAucs);
summaryStats.stdAUC  = std(validAucs);

% Summary Report
summaryPath = fullfile(outputDir, 'vessel_segmentation_summary.txt');
fid = fopen(summaryPath, 'w');
fprintf(fid, '=========================================================================\n');
fprintf(fid, 'RETINASCAN - RETINAL VESSEL SEGMENTATION EVALUATION REPORT\n');
fprintf(fid, 'Dataset: DRIVE Benchmark (Training Set, 1st Observer Manual Ground Truth)\n');
fprintf(fid, 'Evaluation Mask: Strictly inside official field-of-view (FOV) aperture\n');
fprintf(fid, 'Total Images Evaluated: %d\n', numImages);
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'Metric                  Mean       Std Dev    Min        Max\n');
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'Dice Similarity (F1):   %.4f     %.4f     %.4f     %.4f\n', ...
    summaryStats.meanDice, summaryStats.stdDice, min(dices), max(dices));
fprintf(fid, 'Sensitivity (Recall):   %.4f     %.4f     %.4f     %.4f\n', ...
    summaryStats.meanSensitivity, summaryStats.stdSensitivity, min(sens), max(sens));
fprintf(fid, 'Specificity:            %.4f     %.4f     %.4f     %.4f\n', ...
    summaryStats.meanSpecificity, summaryStats.stdSpecificity, min(specs), max(specs));
fprintf(fid, 'Accuracy:               %.4f     %.4f     %.4f     %.4f\n', ...
    summaryStats.meanAccuracy, summaryStats.stdAccuracy, min(accs), max(accs));
fprintf(fid, 'Area Under Curve (AUC): %.4f     %.4f     %.4f     %.4f\n', ...
    summaryStats.meanAUC, summaryStats.stdAUC, min(validAucs), max(validAucs));
fprintf(fid, '=========================================================================\n');
fclose(fid);

fprintf('\nVessel evaluation completed. Summary saved to: %s\n', summaryPath);
type(summaryPath);

end
