function dataTable = load_drive(splitName)
% LOAD_DRIVE Loads DRIVE retinal vessel segmentation dataset paths.
%
% Syntax:
%   dataTable = load_drive()          % Loads training (20) and test (20)
%   dataTable = load_drive('Train')   % Loads training split (with 1st_manual ground truth)
%   dataTable = load_drive('Test')    % Loads test split (with FOV masks)
%
% Output table columns:
%   ImagePath, ImageName, MaskPath, ManualPath, Split

if nargin < 1, splitName = 'All'; end

cfg = dataset_config();
records = {};

% 1. Training set
if strcmpi(splitName, 'All') || strcmpi(splitName, 'Train')
    imgDir    = cfg.drive.train_images;
    maskDir   = cfg.drive.train_masks;
    manualDir = cfg.drive.train_manual;
    
    if exist(imgDir, 'dir')
        imgFiles = dir(fullfile(imgDir, '*_training.tif'));
        for i = 1:numel(imgFiles)
            fName = imgFiles(i).name;
            idStr = fName(1:2);
            imgPath = fullfile(imgDir, fName);
            maskPath = fullfile(maskDir, [idStr, '_training_mask.gif']);
            manPath  = fullfile(manualDir, [idStr, '_manual1.gif']);
            if ~isfile(manPath)
                manPath = fullfile(manualDir, [idStr, '_manual1.tif']);
            end
            records = [records; {imgPath, idStr, maskPath, manPath, 'Train'}]; %#ok<AGROW>
        end
    end
end

% 2. Test set
if strcmpi(splitName, 'All') || strcmpi(splitName, 'Test')
    imgDir    = cfg.drive.test_images;
    maskDir   = cfg.drive.test_masks;
    
    if exist(imgDir, 'dir')
        imgFiles = dir(fullfile(imgDir, '*_test.tif'));
        for i = 1:numel(imgFiles)
            fName = imgFiles(i).name;
            idStr = fName(1:2);
            imgPath = fullfile(imgDir, fName);
            maskPath = fullfile(maskDir, [idStr, '_test_mask.gif']);
            manPath  = ''; % Test set manual labels separate
            records = [records; {imgPath, idStr, maskPath, manPath, 'Test'}]; %#ok<AGROW>
        end
    end
end

dataTable = cell2table(records, 'VariableNames', ...
    {'ImagePath', 'ImageName', 'MaskPath', 'ManualPath', 'Split'});

end
