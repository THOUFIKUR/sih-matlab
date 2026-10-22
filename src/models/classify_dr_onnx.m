function result = classify_dr_onnx(imagePath, modelPath, detTable)
% CLASSIFY_DR_ONNX Evaluates 5-class Diabetic Retinopathy grade using the imported ONNX model.
%
% Syntax:
%   result = classify_dr_onnx(imagePath)
%   result = classify_dr_onnx(imagePath, modelPath)
%   result = classify_dr_onnx(imagePath, modelPath, detTable)

if nargin < 2 || isempty(modelPath)
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    m2Path = fullfile(projectRoot, 'data', 'models 2', 'retina_model.onnx');
    if isfile(m2Path)
        modelPath = m2Path;
    else
        modelPath = fullfile(projectRoot, 'data', 'models', 'retina_efficientnet_b0_scratch.onnx');
    end
end

bridgeScript = fullfile(fileparts(mfilename('fullpath')), 'run_onnx_inference.py');

cmd = sprintf('python "%s" --task classify --image "%s" --model "%s"', ...
    bridgeScript, imagePath, modelPath);

[status, cmdOut] = system(cmd);

if status ~= 0
    error('Classification inference failed: %s', cmdOut);
end

try
    resJson = jsondecode(cmdOut);
    if strcmp(resJson.status, 'success')
        result = resJson;
        if nargin >= 3 && ~isempty(detTable)
            result = arbitrate_dr_grade_from_lesions(result, detTable);
        end
    else
        error('Classifier error: %s', resJson.message);
    end
catch ME
    error('Failed to parse classifier output: %s\nOutput was: %s', ME.message, cmdOut);
end

end
