function results = test_sample_images_smoke()
% TEST_SAMPLE_IMAGES_SMOKE End-to-end smoke test on sample images across DR grades 0-4.
%
% Exercises the complete screening processing chain:
% Quality assessment -> Enhancement -> OD & Fovea -> Vessels -> Lesions -> NV

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')));
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'config')));

results = struct();
testsRun = 0;
testsPassed = 0;

cfg = dataset_config();
samplesDir = cfg.samples_dir;

if ~exist(samplesDir, 'dir')
    gradTable = load_idrid_grading();
    samplePaths = gradTable.ImagePath(1:min(7, height(gradTable)));
    sampleNames = gradTable.ImageName(1:min(7, height(gradTable)));
else
    files = dir(fullfile(samplesDir, '*.jpg'));
    samplePaths = fullfile(samplesDir, {files.name});
    sampleNames = {files.name};
end

fprintf('Running test_sample_images_smoke on %d sample images...\n', numel(samplePaths));

for i = 1:numel(samplePaths)
    testsRun = testsRun + 1;
    imgPath = samplePaths{i};
    imgName = sampleNames{i};
    
    img = imread(imgPath);
    [imgH, imgW, ~] = size(img);
    
    % 1. Quality Gate
    [decision, metrics, msg] = assess_image_quality(img);
    assert(ismember(decision, {'Good', 'Borderline', 'Ungradable'}), 'Invalid quality decision');
    
    % 2. Enhancement
    [enhRGB, ~, meta] = enhance_retinal_image(img);
    assert(isequal(size(enhRGB), size(img)), 'Enhanced size mismatch');
    assert(contains(meta.MethodName, 'CLAHE'), 'Untruthful method name');
    
    % 3. Optic Disc
    [odCenter, odRadius, odMask, odConf] = detect_optic_disc(img);
    assert(odCenter(1) >= 1 && odCenter(1) <= imgW, 'OD Center X out of bounds');
    assert(odCenter(2) >= 1 && odCenter(2) <= imgH, 'OD Center Y out of bounds');
    
    % 4. Fovea
    [foveaCenter, fovConf] = localize_fovea(img, odCenter, odRadius);
    assert(foveaCenter(1) >= 1 && foveaCenter(1) <= imgW, 'Fovea Center X out of bounds');
    assert(foveaCenter(2) >= 1 && foveaCenter(2) <= imgH, 'Fovea Center Y out of bounds');
    
    % 5. Vessels
    [vesselMask, vesselProb, ~] = segment_vessels(img);
    assert(islogical(vesselMask), 'Vessel mask must be logical');
    
    % 6. Lesions
    [maTbl, ~] = detect_microaneurysms(img, vesselMask, odMask);
    [exTbl, ~] = segment_hard_exudates(img, odMask);
    [heTbl, ~] = classify_hemorrhages(img, vesselMask, odMask);
    [nvRpt, ~] = detect_neovascularization(img, vesselMask, odCenter, odRadius);
    
    assert(ismember(nvRpt.uncertaintyLevel, {'Low', 'Moderate', 'High'}), 'Invalid NV uncertainty level');
    
    fprintf('  [PASS] Sample [%d/%d] %s: Quality=%s, OD=(%.1f, %.1f), Fov=(%.1f, %.1f), Cand: MA=%d, EX=%d, HE=%d, NV=%s\n', ...
        i, numel(samplePaths), imgName, decision, odCenter(1), odCenter(2), foveaCenter(1), foveaCenter(2), ...
        height(maTbl), height(exTbl), height(heTbl), nvRpt.uncertaintyLevel);
    testsPassed = testsPassed + 1;
end

results.testsRun = testsRun;
results.testsPassed = testsPassed;
results.allPassed = (testsRun == testsPassed);

end
