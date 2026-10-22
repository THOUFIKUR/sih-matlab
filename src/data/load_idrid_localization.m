function dataTable = load_idrid_localization(splitName)
% LOAD_IDRID_LOCALIZATION Loads IDRiD Optic Disc and Fovea center coordinates.
%
% Syntax:
%   dataTable = load_idrid_localization()          % Loads both Train and Test
%   dataTable = load_idrid_localization('Train')   % Loads Train split (413 images)
%   dataTable = load_idrid_localization('Test')    % Loads Test split (103 images)
%
% Output table columns:
%   ImagePath, ImageName, OD_X, OD_Y, Fovea_X, Fovea_Y, Split

if nargin < 1, splitName = 'All'; end

cfg = dataset_config();
records = {};

% Helper to parse coordinates CSV
function [names, coords] = parseCoordCsv(csvPath)
    opts = detectImportOptions(csvPath);
    opts.VariableNamingRule = 'preserve';
    T = readtable(csvPath, opts);
    colNames = T.Properties.VariableNames;
    nameCol = T{:, 1};
    xCol = double(T{:, 2});
    yCol = double(T{:, 3});
    names = cell(height(T), 1);
    for k = 1:height(T)
        names{k} = char(string(nameCol{k}));
    end
    coords = [xCol, yCol];
end

% 1. Train split
if strcmpi(splitName, 'All') || strcmpi(splitName, 'Train')
    imgDir = cfg.idrid_localization.train_images;
    odCsv  = cfg.idrid_localization.od_train_csv;
    fovCsv = cfg.idrid_localization.fovea_train_csv;
    if isfile(odCsv) && isfile(fovCsv)
        [odNames, odCoords]   = parseCoordCsv(odCsv);
        [fovNames, fovCoords] = parseCoordCsv(fovCsv);
        
        for i = 1:numel(odNames)
            nameStr = odNames{i};
            fileName = [nameStr, '.jpg'];
            fullImgPath = fullfile(imgDir, fileName);
            
            % Match with fovea
            matchIdx = find(strcmp(fovNames, nameStr), 1);
            if ~isempty(matchIdx)
                fX = fovCoords(matchIdx, 1);
                fY = fovCoords(matchIdx, 2);
            else
                fX = NaN; fY = NaN;
            end
            
            records = [records; {fullImgPath, nameStr, odCoords(i, 1), odCoords(i, 2), fX, fY, 'Train'}]; %#ok<AGROW>
        end
    end
end

% 2. Test split
if strcmpi(splitName, 'All') || strcmpi(splitName, 'Test')
    imgDir = cfg.idrid_localization.test_images;
    odCsv  = cfg.idrid_localization.od_test_csv;
    fovCsv = cfg.idrid_localization.fovea_test_csv;
    if isfile(odCsv) && isfile(fovCsv)
        [odNames, odCoords]   = parseCoordCsv(odCsv);
        [fovNames, fovCoords] = parseCoordCsv(fovCsv);
        
        for i = 1:numel(odNames)
            nameStr = odNames{i};
            fileName = [nameStr, '.jpg'];
            fullImgPath = fullfile(imgDir, fileName);
            
            matchIdx = find(strcmp(fovNames, nameStr), 1);
            if ~isempty(matchIdx)
                fX = fovCoords(matchIdx, 1);
                fY = fovCoords(matchIdx, 2);
            else
                fX = NaN; fY = NaN;
            end
            
            records = [records; {fullImgPath, nameStr, odCoords(i, 1), odCoords(i, 2), fX, fY, 'Test'}]; %#ok<AGROW>
        end
    end
end

dataTable = cell2table(records, 'VariableNames', ...
    {'ImagePath', 'ImageName', 'OD_X', 'OD_Y', 'Fovea_X', 'Fovea_Y', 'Split'});

end
