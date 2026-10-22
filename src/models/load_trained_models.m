function models = load_trained_models(modelsDir)
% LOAD_TRAINED_MODELS Loads and verifies the imported ONNX models into MATLAB R2024a.
%
% Models loaded from:
%   D:\RetinaScan_MATLAB_SIH26038\data\models\
%
% Files expected:
%   1. retina_efficientnet_b0_scratch.onnx (5-Class DR Classifier)
%   2. yolo26n_lesions_scratch.onnx        (Multi-Class Lesion Detector)

if nargin < 1 || isempty(modelsDir)
    modelsDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'models');
end

models = struct();
models.classifier = [];
models.detector = [];
models.status = struct('classifierLoaded', false, 'detectorLoaded', false);

%% 1. Load EfficientNet-B0 Classifier
classifierPath = fullfile(modelsDir, 'retina_efficientnet_b0_scratch.onnx');
if isfile(classifierPath)
    try
        fprintf('Loading EfficientNet-B0 Classifier from %s...\n', classifierPath);
        models.classifier = importNetworkFromONNX(classifierPath, 'OutputDataFormats', 'BC');
        models.status.classifierLoaded = true;
        fprintf('  [PASS] Classifier loaded successfully into MATLAB!\n');
    catch ME
        warning('Failed to load classifier: %s', ME.message);
    end
else
    fprintf('Classifier ONNX file not found at: %s\n', classifierPath);
end

%% 2. Load YOLO Lesion Detector (YOLO11n or YOLO26n)
detectorPath = fullfile(modelsDir, 'yolo11n_lesions_scratch.onnx');
if ~isfile(detectorPath)
    detectorPath = fullfile(modelsDir, 'yolo26n_lesions_scratch.onnx');
end

if isfile(detectorPath)
    try
        fprintf('Loading YOLO Lesion Detector from %s...\n', detectorPath);
        models.detector = importNetworkFromONNX(detectorPath, 'OutputDataFormats', 'BC');
        models.status.detectorLoaded = true;
        fprintf('  [PASS] Lesion detector loaded successfully into MATLAB!\n');
    catch ME
        warning('Failed to load lesion detector: %s', ME.message);
    end
else
    fprintf('Lesion detector ONNX file not found (checked yolo11n and yolo26n at %s)\n', modelsDir);
end

end
