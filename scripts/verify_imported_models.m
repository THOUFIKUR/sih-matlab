% VERIFY_IMPORTED_MODELS Runs a test inference on both imported ONNX models.
%
% Usage in MATLAB:
%   run('D:\RetinaScan_MATLAB_SIH26038\scripts\verify_imported_models.m')

clc;
fprintf('=========================================================================\n');
fprintf('RETINASCAN — IMPORTED ONNX MODELS VERIFICATION (MATLAB R2024a)\n');
fprintf('=========================================================================\n\n');

% Add paths
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));

models = load_trained_models();

%% 1. Verify Classifier Inference
if models.status.classifierLoaded
    fprintf('\n--- Testing Classifier Inference ---\n');
    sampleImgPath = 'D:\sih2026\retino\data\samples\idrid_samples\idrid_grade_2.jpg';
    if ~isfile(sampleImgPath)
        sampleImgPath = fullfile(projectRoot, 'data', 'samples', 'idrid_samples', 'idrid_grade_2.jpg');
    end
    
    if isfile(sampleImgPath)
        img = imread(sampleImgPath);
        imgResized = imresize(img, [224, 224]);
        imgSingle = single(imgResized) / 255.0;
        
        % Normalize with standard statistics
        meanVals = reshape([0.485, 0.456, 0.406], [1, 1, 3]);
        stdVals  = reshape([0.229, 0.224, 0.225], [1, 1, 3]);
        imgNorm = (imgSingle - meanVals) ./ stdVals;
        
        dlImg = dlarray(imgNorm, 'SSCB');
        logits = predict(models.classifier, dlImg);
        probs = extractdata(softmax(logits));
        
        grades = {'No DR (0)', 'Mild (1)', 'Moderate (2)', 'Severe (3)', 'Proliferative (4)'};
        [conf, predClass] = max(probs);
        
        fprintf('  Input Image: %s\n', sampleImgPath);
        fprintf('  Predicted Grade: %s\n', grades{predClass});
        fprintf('  Confidence: %.2f%%\n', conf * 100);
        fprintf('  Class Probabilities: %s\n', mat2str(round(probs, 4)));
    else
        fprintf('Sample image not found for inference test.\n');
    end
else
    fprintf('Classifier not loaded. Please ensure retina_efficientnet_b0_scratch.onnx is placed in data/models/\n');
end

%% 2. Verify Lesion Detector Inference
if models.status.detectorLoaded
    fprintf('\n--- Testing Lesion Detector Inference ---\n');
    dummyInput = dlarray(single(rand(1, 3, 1024, 1024)), 'BCSS');
    rawOut = predict(models.detector, dummyInput);
    outData = extractdata(rawOut);
    fprintf('  Detector Forward Pass Output Shape: %s\n', mat2str(size(outData)));
    fprintf('  [PASS] Detector successfully executed forward pass in MATLAB!\n');
else
    fprintf('Detector not loaded. Please ensure yolo11n_lesions_scratch.onnx is placed in data/models/\n');
end

fprintf('\n=========================================================================\n');
