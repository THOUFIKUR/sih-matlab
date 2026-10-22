function results = test_dataset_loaders()
% TEST_DATASET_LOADERS Unit tests for IDRiD and DRIVE loaders.
%
% Tests:
% 1. load_idrid_grading('Train') -> 413 rows
% 2. load_idrid_grading('Test')  -> 103 rows
% 3. load_idrid_localization('Train') -> 413 rows
% 4. load_idrid_localization('Test')  -> 103 rows
% 5. load_idrid_segmentation('Train') -> 54 rows
% 6. load_idrid_segmentation('Test')  -> 27 rows
% 7. load_drive('Train') -> 20 rows
% 8. load_drive('Test')  -> 20 rows

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')));
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'config')));

results = struct();
testsRun = 0;
testsPassed = 0;

fprintf('Running test_dataset_loaders...\n');

% 1. IDRiD Grading Train
testsRun = testsRun + 1;
T_grad_tr = load_idrid_grading('Train');
assert(height(T_grad_tr) == 413, sprintf('Expected 413, got %d', height(T_grad_tr)));
fprintf('  [PASS] IDRiD Grading Train loaded (%d rows)\n', height(T_grad_tr));
testsPassed = testsPassed + 1;

% 2. IDRiD Grading Test
testsRun = testsRun + 1;
T_grad_te = load_idrid_grading('Test');
assert(height(T_grad_te) == 103, sprintf('Expected 103, got %d', height(T_grad_te)));
fprintf('  [PASS] IDRiD Grading Test loaded (%d rows)\n', height(T_grad_te));
testsPassed = testsPassed + 1;

% 3. IDRiD Localization Train
testsRun = testsRun + 1;
T_loc_tr = load_idrid_localization('Train');
assert(height(T_loc_tr) == 413, sprintf('Expected 413, got %d', height(T_loc_tr)));
fprintf('  [PASS] IDRiD Localization Train loaded (%d rows)\n', height(T_loc_tr));
testsPassed = testsPassed + 1;

% 4. IDRiD Localization Test
testsRun = testsRun + 1;
T_loc_te = load_idrid_localization('Test');
assert(height(T_loc_te) == 103, sprintf('Expected 103, got %d', height(T_loc_te)));
fprintf('  [PASS] IDRiD Localization Test loaded (%d rows)\n', height(T_loc_te));
testsPassed = testsPassed + 1;

% 5. IDRiD Segmentation Train
testsRun = testsRun + 1;
T_seg_tr = load_idrid_segmentation('Train');
assert(height(T_seg_tr) == 54, sprintf('Expected 54, got %d', height(T_seg_tr)));
fprintf('  [PASS] IDRiD Segmentation Train loaded (%d rows)\n', height(T_seg_tr));
testsPassed = testsPassed + 1;

% 6. IDRiD Segmentation Test
testsRun = testsRun + 1;
T_seg_te = load_idrid_segmentation('Test');
assert(height(T_seg_te) == 27, sprintf('Expected 27, got %d', height(T_seg_te)));
fprintf('  [PASS] IDRiD Segmentation Test loaded (%d rows)\n', height(T_seg_te));
testsPassed = testsPassed + 1;

% 7. DRIVE Train
testsRun = testsRun + 1;
T_drv_tr = load_drive('Train');
assert(height(T_drv_tr) == 20, sprintf('Expected 20, got %d', height(T_drv_tr)));
fprintf('  [PASS] DRIVE Train loaded (%d rows)\n', height(T_drv_tr));
testsPassed = testsPassed + 1;

% 8. DRIVE Test
testsRun = testsRun + 1;
T_drv_te = load_drive('Test');
assert(height(T_drv_te) == 20, sprintf('Expected 20, got %d', height(T_drv_te)));
fprintf('  [PASS] DRIVE Test loaded (%d rows)\n', height(T_drv_te));
testsPassed = testsPassed + 1;

results.testsRun = testsRun;
results.testsPassed = testsPassed;
results.allPassed = (testsRun == testsPassed);

end
