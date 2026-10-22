function dataTable = load_idrid_segmentation(splitName)
% LOAD_IDRID_SEGMENTATION Loads IDRiD Segmentation images and corresponding ground truth masks.
%
% Syntax:
%   dataTable = load_idrid_segmentation()          % Loads both Train and Test
%   dataTable = load_idrid_segmentation('Train')   % Loads Train split (54 images)
%   dataTable = load_idrid_segmentation('Test')    % Loads Test split (27 images)
%
% Output table columns:
%   ImagePath, ImageName, Mask_MA, Mask_Haemorrhages, Mask_HardExudates, Mask_SoftExudates, Mask_OpticDisc, Split

if nargin < 1, splitName = 'All'; end

cfg = dataset_config();
records = {};

function recs = loadSplit(imgDir, maskDir, splitLabel)
    recs = {};
    if ~exist(imgDir, 'dir') || ~exist(maskDir, 'dir')
        return;
    end
    imgFiles = dir(fullfile(imgDir, '*.jpg'));
    
    for i = 1:numel(imgFiles)
        fName = imgFiles(i).name;
        [~, baseName, ~] = fileparts(fName);
        imgPath = fullfile(imgDir, fName);
        
        % Masks
        maMask  = fullfile(maskDir, '1. Microaneurysms', [baseName, '_MA.tif']);
        heMask  = fullfile(maskDir, '2. Haemorrhages',   [baseName, '_HE.tif']);
        exMask  = fullfile(maskDir, '3. Hard Exudates',  [baseName, '_EX.tif']);
        seMask  = fullfile(maskDir, '4. Soft Exudates',  [baseName, '_SE.tif']);
        odMask  = fullfile(maskDir, '5. Optic Disc',     [baseName, '_OD.tif']);
        
        recs = [recs; {imgPath, baseName, maMask, heMask, exMask, seMask, odMask, splitLabel}]; %#ok<AGROW>
    end
end

if strcmpi(splitName, 'All') || strcmpi(splitName, 'Train')
    recsTrain = loadSplit(cfg.idrid_segmentation.train_images, cfg.idrid_segmentation.train_masks, 'Train');
    records = [records; recsTrain];
end

if strcmpi(splitName, 'All') || strcmpi(splitName, 'Test')
    recsTest = loadSplit(cfg.idrid_segmentation.test_images, cfg.idrid_segmentation.test_masks, 'Test');
    records = [records; recsTest];
end

dataTable = cell2table(records, 'VariableNames', ...
    {'ImagePath', 'ImageName', 'Mask_MA', 'Mask_Haemorrhages', 'Mask_HardExudates', 'Mask_SoftExudates', 'Mask_OpticDisc', 'Split'});

end
