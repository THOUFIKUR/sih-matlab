function detectionsTable = detect_lesions_onnx(imagePath, modelPath, confThresh, iouThresh)
% DETECT_LESIONS_ONNX Runs multi-class retinal lesion detection using the imported YOLO11n ONNX model.
%
% Syntax:
%   detectionsTable = detect_lesions_onnx(imagePath)
%   detectionsTable = detect_lesions_onnx(imagePath, modelPath, confThresh, iouThresh)
%
% Output:
%   detectionsTable: MATLAB table with columns [ClassID, ClassName, Confidence, X1, Y1, X2, Y2, Width, Height]

if nargin < 2 || isempty(modelPath)
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    bestPath = fullfile(projectRoot, 'data', 'models', 'best.onnx');
    if isfile(bestPath)
        modelPath = bestPath;
    else
        modelPath = fullfile(projectRoot, 'data', 'models', 'yolo11n_lesions_scratch.onnx');
    end
end
if nargin < 3 || isempty(confThresh)
    confThresh = 0.10;
end
if nargin < 4 || isempty(iouThresh)
    iouThresh = 0.45;
end

bridgeScript = fullfile(fileparts(mfilename('fullpath')), 'run_onnx_inference.py');

cmd = sprintf('python "%s" --task detect --image "%s" --model "%s" --conf %.2f --iou %.2f', ...
    bridgeScript, imagePath, modelPath, confThresh, iouThresh);

[status, cmdOut] = system(cmd);

if status ~= 0
    error('Detection inference failed: %s', cmdOut);
end

try
    resJson = jsondecode(cmdOut);
    if ~strcmp(resJson.status, 'success')
        error('Detector error: %s', resJson.message);
    end
    
    dets = resJson.detections;
    if isempty(dets)
        detectionsTable = table([], [], [], [], [], [], [], [], [], {}, ...
            'VariableNames', {'ClassID', 'ClassName', 'Confidence', 'X1', 'Y1', 'X2', 'Y2', 'Width', 'Height', 'ModelSource'});
        return;
    end
    
    n = numel(dets);
    classIds = zeros(n, 1);
    classNames = cell(n, 1);
    confs = zeros(n, 1);
    x1s = zeros(n, 1);
    y1s = zeros(n, 1);
    x2s = zeros(n, 1);
    y2s = zeros(n, 1);
    modelSources = cell(n, 1);
    
    for i = 1:n
        classIds(i) = dets(i).class_id;
        classNames{i} = dets(i).class_name;
        confs(i) = dets(i).confidence;
        b = dets(i).bbox;
        x1s(i) = b(1);
        y1s(i) = b(2);
        x2s(i) = b(3);
        y2s(i) = b(4);
        if isfield(dets(i), 'model_source')
            modelSources{i} = dets(i).model_source;
        else
            modelSources{i} = 'YOLO';
        end
    end
    
    ws = x2s - x1s;
    hs = y2s - y1s;
    
    detectionsTable = table(classIds, classNames, confs, x1s, y1s, x2s, y2s, ws, hs, modelSources, ...
        'VariableNames', {'ClassID', 'ClassName', 'Confidence', 'X1', 'Y1', 'X2', 'Y2', 'Width', 'Height', 'ModelSource'});
catch ME
    error('Failed to parse detector output: %s\nOutput was: %s', ME.message, cmdOut);
end

end
