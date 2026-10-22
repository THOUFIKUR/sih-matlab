function [overlayImg, summaryStats] = overlay_lesion_detections(rawImg, detectionsTable, showLabels)
% OVERLAY_LESION_DETECTIONS Overlays bounding boxes and confidence tags on a retinal image.
%
% Color Scheme:
%   Microaneurysms (MA):                Yellow [255, 235, 59]
%   Haemorrhages (HE):                  Red    [244, 67, 54]
%   Hard Exudates (EX):                 Green  [76, 175, 80]
%   Soft Exudates (SE):                 Cyan   [0, 188, 212]
%   Compound / Bleeding / Scarring:     Magenta [233, 30, 99] or Orange [255, 152, 0]

if nargin < 3 || isempty(showLabels)
    showLabels = true;
end

if ischar(rawImg) || isstring(rawImg)
    rawImg = imread(rawImg);
end

overlayImg = rawImg;
[imgH, imgW, ~] = size(rawImg);

summaryStats = struct(...
    'totalDetections', 0, ...
    'numMA', 0, ...
    'numHE', 0, ...
    'numEX', 0, ...
    'numSE', 0, ...
    'numOther', 0);

if isempty(detectionsTable) || height(detectionsTable) == 0
    return;
end

summaryStats.totalDetections = height(detectionsTable);

% Canonical IDRiD counts
cNames = lower(detectionsTable.ClassName);
summaryStats.numMA = sum(contains(cNames, 'microaneurysm') & ~contains(cNames, 'hemorrhage'));
summaryStats.numHE = sum(contains(cNames, 'haemorrhage') | contains(cNames, 'hemorrhage') & ~contains(cNames, 'microaneurysm'));
summaryStats.numEX = sum(contains(cNames, 'hard exudate') | (contains(cNames, 'exudate') & ~contains(cNames, 'cotton')));
summaryStats.numSE = sum(contains(cNames, 'soft exudate') | contains(cNames, 'cotton'));
summaryStats.numOther = summaryStats.totalDetections - (summaryStats.numMA + summaryStats.numHE + summaryStats.numEX + summaryStats.numSE);

lineThickness = max(2, round(min(imgH, imgW) / 450));

textPositions = [];
textStrings = {};
textColors = [];

for i = 1:height(detectionsTable)
    cName = detectionsTable.ClassName{i};
    conf = detectionsTable.Confidence(i);
    
    x1 = max(1, round(detectionsTable.X1(i)));
    y1 = max(1, round(detectionsTable.Y1(i)));
    x2 = min(imgW, round(detectionsTable.X2(i)));
    y2 = min(imgH, round(detectionsTable.Y2(i)));
    
    % Determine color and legible clinical tag
    lowerName = lower(cName);
    if contains(lowerName, 'microaneurysm') && ~contains(lowerName, 'hemorrhage')
        rgbCol = uint8([255, 235, 59]); % Yellow
        fullTag = 'Microaneurysm';
    elseif contains(lowerName, 'haemorrhage') || (contains(lowerName, 'hemorrhage') && ~contains(lowerName, 'microaneurysm'))
        rgbCol = uint8([244, 67, 54]);  % Red
        fullTag = 'Haemorrhage';
    elseif contains(lowerName, 'hard exudate')
        rgbCol = uint8([76, 175, 80]);  % Green
        fullTag = 'Hard Exudate';
    elseif contains(lowerName, 'soft exudate') || contains(lowerName, 'cotton')
        rgbCol = uint8([0, 188, 212]);  % Cyan / Light Blue
        fullTag = 'Soft Exudate';
    elseif contains(lowerName, 'microaneurysms hemorrhages')
        rgbCol = uint8([255, 152, 0]);  % Amber/Orange
        fullTag = 'MA / Hemorrhage';
    elseif contains(lowerName, 'external bleeding')
        rgbCol = uint8([198, 40, 40]);  % Dark Red
        fullTag = 'Bleeding';
    elseif contains(lowerName, 'scarring')
        rgbCol = uint8([156, 39, 176]); % Purple
        fullTag = 'Retinal Scarring';
    else
        rgbCol = uint8([0, 188, 212]);
        fullTag = cName;
    end
    
    % Draw box borders
    for t = 0:(lineThickness-1)
        if (y1 + t) <= imgH
            overlayImg(y1 + t, x1:x2, 1) = rgbCol(1);
            overlayImg(y1 + t, x1:x2, 2) = rgbCol(2);
            overlayImg(y1 + t, x1:x2, 3) = rgbCol(3);
        end
        if (y2 - t) >= 1
            overlayImg(y2 - t, x1:x2, 1) = rgbCol(1);
            overlayImg(y2 - t, x1:x2, 2) = rgbCol(2);
            overlayImg(y2 - t, x1:x2, 3) = rgbCol(3);
        end
        if (x1 + t) <= imgW
            overlayImg(y1:y2, x1 + t, 1) = rgbCol(1);
            overlayImg(y1:y2, x1 + t, 2) = rgbCol(2);
            overlayImg(y1:y2, x1 + t, 3) = rgbCol(3);
        end
        if (x2 - t) >= 1
            overlayImg(y1:y2, x2 - t, 1) = rgbCol(1);
            overlayImg(y1:y2, x2 - t, 2) = rgbCol(2);
            overlayImg(y1:y2, x2 - t, 3) = rgbCol(3);
        end
    end
    
    % Compact, refined font size to avoid visual clutter
    fontSize = max(10, round(min(imgH, imgW) / 95));
    offsetY = round(fontSize * 1.35);
    
    lblStr = sprintf('%s %.2f', fullTag, conf);
    textStrings{end+1} = lblStr; %#ok<AGROW>
    textPositions(end+1, :) = [max(2, x1), max(2, y1 - offsetY)]; %#ok<AGROW>
    textColors(end+1, :) = double(rgbCol); %#ok<AGROW>
end

% Render labels
if showLabels && ~isempty(textStrings)
    hasInserted = false;
    try
        fontSize = max(10, round(min(imgH, imgW) / 95));
        overlayImg = insertText(overlayImg, textPositions, textStrings, ...
            'FontSize', fontSize, ...
            'BoxColor', textColors, ...
            'BoxOpacity', 0.85, ...
            'TextColor', 'black');
        hasInserted = true;
    catch
    end
    
    % If insertText is unavailable (e.g. missing Computer Vision Toolbox license),
    % render via python OpenCV script
    if ~hasInserted
        try
            tempDir = fullfile(tempdir, 'retinascan');
            if ~exist(tempDir, 'dir'), mkdir(tempDir); end
            tmpIn  = fullfile(tempDir, 'in_ov.jpg');
            tmpOut = fullfile(tempDir, 'out_ov.jpg');
            tmpJson = fullfile(tempDir, 'dets.json');
            
            imwrite(rawImg, tmpIn);
            
            % Save detections table to json
            dStruct = table2struct(detectionsTable);
            fid = fopen(tmpJson, 'w');
            fwrite(fid, jsonencode(dStruct));
            fclose(fid);
            
            pyScript = fullfile(fileparts(mfilename('fullpath')), 'render_labeled_boxes.py');
            cmd = sprintf('python "%s" --image_path "%s" --dets_json "%s" --output_path "%s"', pyScript, tmpIn, tmpJson, tmpOut);
            [st, ~] = system(cmd);
            if st == 0 && isfile(tmpOut)
                overlayImg = imread(tmpOut);
            end
        catch
        end
    end
end

end
