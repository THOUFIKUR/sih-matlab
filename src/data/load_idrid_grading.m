function dataTable = load_idrid_grading(splitName)
% LOAD_IDRID_GRADING Loads IDRiD Disease Grading dataset metadata and filepaths.
%
% Syntax:
%   dataTable = load_idrid_grading()          % Loads both Train and Test
%   dataTable = load_idrid_grading('Train')   % Loads Train split (413 images)
%   dataTable = load_idrid_grading('Test')    % Loads Test split (103 images)
%
% Output table columns:
%   ImagePath, ImageName, RetinopathyGrade, RiskOfDME, Split

if nargin < 1, splitName = 'All'; end

cfg = dataset_config();
records = {};

% 1. Train split
if strcmpi(splitName, 'All') || strcmpi(splitName, 'Train')
    csvPath = cfg.idrid_grading.train_labels;
    imgDir  = cfg.idrid_grading.train_images;
    if isfile(csvPath)
        opts = detectImportOptions(csvPath);
        opts.VariableNamingRule = 'preserve';
        T = readtable(csvPath, opts);
        
        imgCol = T{:, 1};
        gradeCol = T{:, 2};
        dmeCol = T{:, 3};
        
        for i = 1:height(T)
            nameStr = char(string(imgCol{i}));
            if ~endsWith(nameStr, '.jpg', 'IgnoreCase', true)
                fileName = [nameStr, '.jpg'];
            else
                fileName = nameStr;
            end
            fullImgPath = fullfile(imgDir, fileName);
            records = [records; {fullImgPath, nameStr, double(gradeCol(i)), double(dmeCol(i)), 'Train'}]; %#ok<AGROW>
        end
    end
end

% 2. Test split
if strcmpi(splitName, 'All') || strcmpi(splitName, 'Test')
    csvPath = cfg.idrid_grading.test_labels;
    imgDir  = cfg.idrid_grading.test_images;
    if isfile(csvPath)
        opts = detectImportOptions(csvPath);
        opts.VariableNamingRule = 'preserve';
        T = readtable(csvPath, opts);
        
        imgCol = T{:, 1};
        gradeCol = T{:, 2};
        dmeCol = T{:, 3};
        
        for i = 1:height(T)
            nameStr = char(string(imgCol{i}));
            if ~endsWith(nameStr, '.jpg', 'IgnoreCase', true)
                fileName = [nameStr, '.jpg'];
            else
                fileName = nameStr;
            end
            fullImgPath = fullfile(imgDir, fileName);
            records = [records; {fullImgPath, nameStr, double(gradeCol(i)), double(dmeCol(i)), 'Test'}]; %#ok<AGROW>
        end
    end
end

dataTable = cell2table(records, 'VariableNames', ...
    {'ImagePath', 'ImageName', 'RetinopathyGrade', 'RiskOfDME', 'Split'});

end
