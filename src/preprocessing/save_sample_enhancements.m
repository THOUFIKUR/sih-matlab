function save_sample_enhancements()
% SAVE_SAMPLE_ENHANCEMENTS Generates and saves original/enhanced pairs with histograms.
%
% Truthfully evaluates adaptive CLAHE on luminance and illumination normalization,
% saving comparison figures and histogram analysis for sample fundus images across grades.

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

outputDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'outputs', 'validation', 'enhancement_pairs');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

cfg = dataset_config();
samplesDir = cfg.samples_dir;

if ~exist(samplesDir, 'dir')
    % Fallback to first few IDRiD grading images
    gradTable = load_idrid_grading();
    samplePaths = gradTable.ImagePath(1:min(5, height(gradTable)));
    sampleNames = gradTable.ImageName(1:min(5, height(gradTable)));
else
    files = dir(fullfile(samplesDir, '*.jpg'));
    samplePaths = fullfile(samplesDir, {files.name});
    sampleNames = {files.name};
end

fprintf('Generating enhancement pairs and histograms for %d sample images...\n', numel(samplePaths));

for i = 1:numel(samplePaths)
    p = samplePaths{i};
    [~, baseName, ~] = fileparts(sampleNames{i});
    figSavePath = fullfile(outputDir, sprintf('enhancement_pair_%s.png', baseName));
    
    [enhancedRGB, ~, meta] = enhance_retinal_image(p, figSavePath);
    
    fprintf('  [%d/%d] Saved enhancement comparison for %s -> %s\n', ...
        i, numel(samplePaths), baseName, figSavePath);
end

fprintf('Completed all enhancement pair exports. Method: %s\n', meta.MethodName);

end
