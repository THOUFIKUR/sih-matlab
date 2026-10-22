function summaryStats = evaluate_lesions(maxImages)
% EVALUATE_LESIONS Evaluates candidate lesion detection on IDRiD Segmentation Test Split.
%
% Evaluates candidate findings for Microaneurysms (MA), Haemorrhages (HE),
% and Hard Exudates (EX) against the official IDRiD ground truth masks (27 test images).
%
% Syntax:
%   summaryStats = evaluate_lesions()
%   summaryStats = evaluate_lesions(maxImages)
%
% Note: All methods are candidate screening extractors; results are labeled strictly
% as "Candidate Findings", NOT confirmed clinical diagnoses.

if nargin < 1 || isempty(maxImages)
    maxImages = Inf;
end

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

outputDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'outputs', 'validation');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

fprintf('=== EVALUATING LESION CANDIDATES (IDRiD Segmentation Test Set) ===\n');

testTable = load_idrid_segmentation('Test');
numImages = min(height(testTable), maxImages);
fprintf('Total images to evaluate: %d (Split: IDRiD Segmentation Official Test Split)\n', numImages);

results = cell(numImages, 10);

maDice = []; maSens = []; maPrec = [];
heDice = []; heSens = []; hePrec = [];
exDice = []; exSens = []; exPrec = [];

for i = 1:numImages
    imgPath = testTable.ImagePath{i};
    imgName = testTable.ImageName{i};
    maPath  = testTable.Mask_MA{i};
    hePath  = testTable.Mask_Haemorrhages{i};
    exPath  = testTable.Mask_HardExudates{i};
    
    if ~isfile(imgPath)
        warning('Image not found: %s', imgPath);
        continue;
    end
    
    img = imread(imgPath);
    [imgH, imgW, ~] = size(img);
    
    % Retinal FOV
    gray = rgb2gray(img);
    retinaMask = (gray > 15);
    retinaMask = imopen(retinaMask, strel('disk', 5));
    retinaMask = imfill(retinaMask, 'holes');
    
    % Ancillary structures
    [odCenter, odRadius, odMask, ~] = detect_optic_disc(img);
    vesselMask = segment_vessels(img, retinaMask);
    
    % 1. Microaneurysms Candidates
    [maTable, predMAMask] = detect_microaneurysms(img, vesselMask, odMask);
    
    % 2. Hard Exudates Candidates
    [exTable, predEXMask] = segment_hard_exudates(img, odMask, retinaMask);
    
    % 3. Hemorrhages Candidates
    [heTable, predHEMask] = classify_hemorrhages(img, vesselMask, odMask, retinaMask);
    
    % 4. Neovascularization Candidates
    [nvReport, ~] = detect_neovascularization(img, vesselMask, odCenter, odRadius, retinaMask);
    
    [mDice, mSens, mPrec] = calcMetrics(predMAMask, maPath, retinaMask);
    [hDice, hSens, hPrec] = calcMetrics(predHEMask, hePath, retinaMask);
    [eDice, eSens, ePrec] = calcMetrics(predEXMask, exPath, retinaMask);
    
    if ~isnan(mDice), maDice = [maDice; mDice]; maSens = [maSens; mSens]; maPrec = [maPrec; mPrec]; end %#ok<AGROW>
    if ~isnan(hDice), heDice = [heDice; hDice]; heSens = [heSens; hSens]; hePrec = [hePrec; hPrec]; end %#ok<AGROW>
    if ~isnan(eDice), exDice = [exDice; eDice]; exSens = [exSens; eSens]; exPrec = [exPrec; ePrec]; end %#ok<AGROW>
    
    results{i, 1} = imgName;
    results{i, 2} = mDice;
    results{i, 3} = mSens;
    results{i, 4} = hDice;
    results{i, 5} = hSens;
    results{i, 6} = eDice;
    results{i, 7} = eSens;
    results{i, 8} = height(maTable);
    results{i, 9} = height(heTable);
    results{i, 10} = height(exTable);
    
    fprintf('  [%d/%d] %s: MA Dice=%.4f (Sens=%.4f), HE Dice=%.4f (Sens=%.4f), EX Dice=%.4f (Sens=%.4f)\n', ...
        i, numImages, imgName, mDice, mSens, hDice, hSens, eDice, eSens);
end

% Per-image results table
resTable = cell2table(results(1:numImages, :), 'VariableNames', ...
    {'ImageName', 'MA_Pixel_Dice', 'MA_Pixel_Sens', 'HE_Pixel_Dice', 'HE_Pixel_Sens', ...
     'EX_Pixel_Dice', 'EX_Pixel_Sens', 'MA_Candidate_Count', 'HE_Candidate_Count', 'EX_Candidate_Count'});

csvPath = fullfile(outputDir, 'lesion_metrics.csv');
writetable(resTable, csvPath);
fprintf('Saved per-image lesion metrics to: %s\n', csvPath);

% Summary stats
summaryStats = struct();
summaryStats.numEvaluated = numImages;
summaryStats.maMeanDice = mean(maDice);
summaryStats.maMeanSens = mean(maSens);
summaryStats.maMeanPrec = mean(maPrec);
summaryStats.heMeanDice = mean(heDice);
summaryStats.heMeanSens = mean(heSens);
summaryStats.heMeanPrec = mean(hePrec);
summaryStats.exMeanDice = mean(exDice);
summaryStats.exMeanSens = mean(exSens);
summaryStats.exMeanPrec = mean(exPrec);

% Summary report
summaryPath = fullfile(outputDir, 'lesion_summary.txt');
fid = fopen(summaryPath, 'w');
fprintf(fid, '=========================================================================\n');
fprintf(fid, 'RETINASCAN - LESION CANDIDATES EVALUATION REPORT\n');
fprintf(fid, 'Dataset: IDRiD Segmentation Challenge (Official Testing Set)\n');
fprintf(fid, 'Evaluation Type: Pixel-Level Segmentation & Candidate Findings Detection\n');
fprintf(fid, 'Total Images Evaluated: %d\n', numImages);
fprintf(fid, 'Note: Labeled strictly as CANDIDATE FINDINGS, not confirmed clinical diagnoses.\n');
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'Lesion Target       Pixel Dice (Mean)   Pixel Recall/Sens   Pixel Precision\n');
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'Microaneurysms:     %.4f              %.4f              %.4f\n', ...
    summaryStats.maMeanDice, summaryStats.maMeanSens, summaryStats.maMeanPrec);
fprintf(fid, 'Haemorrhages:       %.4f              %.4f              %.4f\n', ...
    summaryStats.heMeanDice, summaryStats.heMeanSens, summaryStats.heMeanPrec);
fprintf(fid, 'Hard Exudates:      %.4f              %.4f              %.4f\n', ...
    summaryStats.exMeanDice, summaryStats.exMeanSens, summaryStats.exMeanPrec);
fprintf(fid, '=========================================================================\n');
fclose(fid);

fprintf('\nLesion evaluation completed. Summary saved to: %s\n', summaryPath);
type(summaryPath);

end

function [diceVal, sensVal, precVal] = calcMetrics(predM, gtPath, retinaMask)
    if isfile(gtPath)
        rawGt = imread(gtPath);
        if ndims(rawGt) > 2
            rawGt = rawGt(:, :, 1);
        end
        gtM = logical(rawGt > 0);
        if ~isequal(size(gtM), size(predM))
            gtM = imresize(gtM, size(predM), 'nearest');
        end
        
        p = logical(predM > 0) & logical(retinaMask > 0);
        g = logical(gtM > 0) & logical(retinaMask > 0);
        
        TP = sum(p(:) & g(:));
        FP = sum(p(:) & ~g(:));
        FN = sum(~p(:) & g(:));
        
        if (sum(g(:)) == 0) && (sum(p(:)) == 0)
            diceVal = 1.0;
            sensVal = 1.0;
            precVal = 1.0;
        elseif (sum(g(:)) == 0) && (sum(p(:)) > 0)
            diceVal = 0.0;
            sensVal = 1.0;
            precVal = 0.0;
        else
            diceVal = (2 * TP) / (2 * TP + FP + FN + eps);
            sensVal = TP / (TP + FN + eps);
            precVal = TP / (TP + FP + eps);
        end
    else
        diceVal = NaN; sensVal = NaN; precVal = NaN;
    end
end
