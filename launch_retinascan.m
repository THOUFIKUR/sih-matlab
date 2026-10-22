% LAUNCH_RETINASCAN Main entry point for the standalone RetinaScan MATLAB application.
%
% Problem Statement: SIH 26038 (MathWorks) — Explainable AI for Diabetic Retinopathy Screening in Rural India
% Target: MATLAB R2024a on Windows 11
%
% Usage:
%   launch_retinascan

clc;
fprintf('=========================================================================\n');
fprintf('RETINASCAN AI — DIABETIC RETINOPATHY SCREENING PLATFORM (SIH 26038)\n');
fprintf('Target: Primary Health Centres in Rural India\n');
fprintf('=========================================================================\n\n');

% 1. Add All Project Subdirectories to Path
projectRoot = fileparts(mfilename('fullpath'));
fprintf('Configuring environment paths for %s...\n', projectRoot);
addpath(genpath(projectRoot));

% 2. Verify Models
classifierPath = fullfile(projectRoot, 'data', 'models', 'retina_efficientnet_b0_scratch.onnx');
detectorPath   = fullfile(projectRoot, 'data', 'models', 'yolo11n_lesions_scratch.onnx');
suppDetectorPath = fullfile(projectRoot, 'data', 'models 2', 'yolo_lesions.onnx');
expClassifierPath = fullfile(projectRoot, 'data', 'models 2', 'retina_model.onnx');

if isfile(expClassifierPath)
    fprintf('  [FOUND] Primary Classifier (EfficientNet-B0 retina_model.onnx): %s (%.1f MB)\n', expClassifierPath, dir(expClassifierPath).bytes / 1e6);
elseif isfile(classifierPath)
    fprintf('  [FOUND] Fallback Classifier (EfficientNet-B0 Scratch): %s (%.1f MB)\n', classifierPath, dir(classifierPath).bytes / 1e6);
else
    fprintf('  [NOTICE] Classifier ONNX not found at %s\n', classifierPath);
end

if isfile(detectorPath)
    fprintf('  [FOUND] Primary Lesion Detector (YOLO11n IDRiD 4-Class): %s (%.1f MB)\n', detectorPath, dir(detectorPath).bytes / 1e6);
else
    fprintf('  [NOTICE] Primary Lesion Detector ONNX not found at %s\n', detectorPath);
end

if isfile(suppDetectorPath)
    fprintf('  [FOUND] Supplementary Detector (YOLOv8 Roboflow 1024px): %s (%.1f MB)\n', suppDetectorPath, dir(suppDetectorPath).bytes / 1e6);
else
    fprintf('  [NOTICE] Supplementary YOLO detector not found at %s\n', suppDetectorPath);
end

% 3. Launch App Designer Interface
fprintf('\nLaunching RetinaScan App Designer Interface...\n');
try
    % Close any existing off-screen figure instances
    existingFigs = findall(0, 'Type', 'figure', 'Name', 'RetinaScan AI — Diabetic Retinopathy Screening System (SIH 26038)');
    if ~isempty(existingFigs)
        delete(existingFigs);
    end
    
    appInstance = RetinaScanApp();
    fprintf('RetinaScan App successfully opened and running!\n');
catch ME
    fprintf('[ERROR] Could not initialize UI: %s\n', ME.message);
    rethrow(ME);
end

fprintf('=========================================================================\n');
