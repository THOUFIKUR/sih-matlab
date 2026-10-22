function summaryStats = evaluate_localization(maxImages)
% EVALUATE_LOCALIZATION Evaluates Optic Disc and Fovea localization on IDRiD Test Set.
%
% Evaluates on the official IDRiD Localization Testing Set (103 images).
%
% Syntax:
%   summaryStats = evaluate_localization()          % Runs full test set (103 images)
%   summaryStats = evaluate_localization(maxImages) % Runs subset for testing
%
% Outputs:
%   summaryStats: Struct with OD & Fovea mean/median pixel error, ODD error, and success rate.

if nargin < 1 || isempty(maxImages)
    maxImages = Inf;
end

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

outputDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'outputs', 'validation');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

fprintf('=== EVALUATING OPTIC DISC & FOVEA LOCALIZATION (IDRiD Test Set) ===\n');

testTable = load_idrid_localization('Test');
numImages = min(height(testTable), maxImages);
fprintf('Total images to evaluate: %d\n', numImages);

results = cell(numImages, 8);

odPixelErrors = [];
odOddErrors   = [];
fovPixelErrors = [];
fovOddErrors  = [];

for i = 1:numImages
    imgPath = testTable.ImagePath{i};
    imgName = testTable.ImageName{i};
    gtOD    = [testTable.OD_X(i), testTable.OD_Y(i)];
    gtFov   = [testTable.Fovea_X(i), testTable.Fovea_Y(i)];
    
    if ~isfile(imgPath)
        warning('Image not found: %s', imgPath);
        continue;
    end
    
    img = imread(imgPath);
    
    % 1. Optic Disc detection
    [predOD, odRadius, ~, ~] = detect_optic_disc(img);
    oddPx = 2 * odRadius;
    
    odErrPx = norm(predOD - gtOD);
    odErrODD = odErrPx / oddPx;
    
    odPixelErrors = [odPixelErrors; odErrPx]; %#ok<AGROW>
    odOddErrors   = [odOddErrors; odErrODD];   %#ok<AGROW>
    
    % 2. Fovea localization
    if ~isnan(gtFov(1))
        [predFov, ~] = localize_fovea(img, predOD, odRadius);
        fovErrPx = norm(predFov - gtFov);
        fovErrODD = fovErrPx / oddPx;
        
        fovPixelErrors = [fovPixelErrors; fovErrPx]; %#ok<AGROW>
        fovOddErrors   = [fovOddErrors; fovErrODD];   %#ok<AGROW>
    else
        fovErrPx = NaN;
        fovErrODD = NaN;
    end
    
    results{i, 1} = imgName;
    results{i, 2} = odErrPx;
    results{i, 3} = odErrODD;
    results{i, 4} = (odErrODD <= 1.0);
    results{i, 5} = fovErrPx;
    results{i, 6} = fovErrODD;
    results{i, 7} = (fovErrODD <= 1.0);
    results{i, 8} = oddPx;
    
    if mod(i, 20) == 0 || i == numImages
        fprintf('  Processed [%d / %d] images...\n', i, numImages);
    end
end

% Construct Per-Image Results Table
resTable = cell2table(results(1:numImages, :), 'VariableNames', ...
    {'ImageName', 'OD_Pixel_Error', 'OD_Error_ODD', 'OD_Success_1ODD', ...
     'Fovea_Pixel_Error', 'Fovea_Error_ODD', 'Fovea_Success_1ODD', 'OD_Diameter_Px'});

csvPath = fullfile(outputDir, 'localization_metrics.csv');
writetable(resTable, csvPath);
fprintf('Saved per-image metrics to: %s\n', csvPath);

% Summary statistics
summaryStats = struct();
summaryStats.numEvaluated = numImages;
summaryStats.odMeanPixelError   = mean(odPixelErrors);
summaryStats.odMedianPixelError = median(odPixelErrors);
summaryStats.odMeanOddError     = mean(odOddErrors);
summaryStats.odMedianOddError   = median(odOddErrors);
summaryStats.odSuccessRate      = 100 * mean(odOddErrors <= 1.0);

validFovIdx = ~isnan(fovPixelErrors);
summaryStats.foveaEvaluatedCount  = sum(validFovIdx);
summaryStats.foveaMeanPixelError   = mean(fovPixelErrors(validFovIdx));
summaryStats.foveaMedianPixelError = median(fovPixelErrors(validFovIdx));
summaryStats.foveaMeanOddError     = mean(fovOddErrors(validFovIdx));
summaryStats.foveaMedianOddError   = median(fovOddErrors(validFovIdx));
summaryStats.foveaSuccessRate      = 100 * mean(fovOddErrors(validFovIdx) <= 1.0);

% Write summary report
summaryPath = fullfile(outputDir, 'localization_summary.txt');
fid = fopen(summaryPath, 'w');
fprintf(fid, '=========================================================================\n');
fprintf(fid, 'RETINASCAN - OPTIC DISC & FOVEA LOCALIZATION EVALUATION REPORT\n');
fprintf(fid, 'Dataset: IDRiD Localization Challenge (Official Testing Set)\n');
fprintf(fid, 'Total Images Evaluated: %d\n', numImages);
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'OPTIC DISC LOCALIZATION:\n');
fprintf(fid, '  Mean Pixel Error:             %.2f px\n', summaryStats.odMeanPixelError);
fprintf(fid, '  Median Pixel Error:           %.2f px\n', summaryStats.odMedianPixelError);
fprintf(fid, '  Mean Error (in Disc Diameters): %.4f ODD\n', summaryStats.odMeanOddError);
fprintf(fid, '  Median Error (in Disc Diameters): %.4f ODD\n', summaryStats.odMedianOddError);
fprintf(fid, '  Success Rate (<= 1.0 ODD):    %.2f %%\n', summaryStats.odSuccessRate);
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'FOVEA CENTRALIS LOCALIZATION:\n');
fprintf(fid, '  Fovea Coordinates Evaluated:  %d\n', summaryStats.foveaEvaluatedCount);
fprintf(fid, '  Mean Pixel Error:             %.2f px\n', summaryStats.foveaMeanPixelError);
fprintf(fid, '  Median Pixel Error:           %.2f px\n', summaryStats.foveaMedianPixelError);
fprintf(fid, '  Mean Error (in Disc Diameters): %.4f ODD\n', summaryStats.foveaMeanOddError);
fprintf(fid, '  Median Error (in Disc Diameters): %.4f ODD\n', summaryStats.foveaMedianOddError);
fprintf(fid, '  Success Rate (<= 1.0 ODD):    %.2f %%\n', summaryStats.foveaSuccessRate);
fprintf(fid, '=========================================================================\n');
fclose(fid);

fprintf('\nEvaluation completed. Summary saved to: %s\n', summaryPath);
type(summaryPath);

end
