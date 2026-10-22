function results = test_quality_gate()
% TEST_QUALITY_GATE Unit tests for fail-closed quality gate (assess_image_quality.m).
%
% Tests:
% 1. Blank image (all zeros) -> Must return 'Ungradable'
% 2. Overexposed image (all 255) -> Must return 'Ungradable'
% 3. Grayscale 2D image -> Handled gracefully, returns ungradable or valid
% 4. Wrong-size / tiny image (10x10) -> Must return 'Ungradable'
% 5. Non-existent file path -> Must fail closed and return 'Ungradable'
% 6. Thrown exception / corrupt input -> Must fail closed and return 'Ungradable'

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')));
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'config')));

results = struct();
testsRun = 0;
testsPassed = 0;

fprintf('Running test_quality_gate...\n');

% Test 1: Blank image (zeros)
testsRun = testsRun + 1;
blankImg = zeros(500, 500, 3, 'uint8');
[dec1, ~, ~] = assess_image_quality(blankImg);
assert(strcmp(dec1, 'Ungradable'), 'Test 1 Failed: Blank image must return Ungradable');
fprintf('  [PASS] Test 1: Blank image returned Ungradable\n');
testsPassed = testsPassed + 1;

% Test 2: Overexposed image (255)
testsRun = testsRun + 1;
overImg = 255 * ones(500, 500, 3, 'uint8');
[dec2, ~, ~] = assess_image_quality(overImg);
assert(strcmp(dec2, 'Ungradable'), 'Test 2 Failed: Overexposed image must return Ungradable');
fprintf('  [PASS] Test 2: Overexposed image returned Ungradable\n');
testsPassed = testsPassed + 1;

% Test 3: Grayscale 2D matrix
testsRun = testsRun + 1;
grayImg = uint8(randi([20, 180], 300, 300));
[dec3, ~, ~] = assess_image_quality(grayImg);
assert(ismember(dec3, {'Good', 'Borderline', 'Ungradable'}), 'Test 3 Failed: Grayscale input error');
fprintf('  [PASS] Test 3: Grayscale 2D image handled gracefully (Decision: %s)\n', dec3);
testsPassed = testsPassed + 1;

% Test 4: Tiny wrong-size image (10x10)
testsRun = testsRun + 1;
tinyImg = uint8(randi([0, 255], 10, 10, 3));
[dec4, ~, ~] = assess_image_quality(tinyImg);
assert(strcmp(dec4, 'Ungradable'), 'Test 4 Failed: Tiny image must return Ungradable');
fprintf('  [PASS] Test 4: Tiny wrong-size image returned Ungradable\n');
testsPassed = testsPassed + 1;

% Test 5: Non-existent / unreadable file path
testsRun = testsRun + 1;
fakePath = 'D:\NonExistent_Corrupt_Folder\missing_retina.jpg';
[dec5, ~, ~] = assess_image_quality(fakePath);
assert(ismember(dec5, {'Ungradable', 'AssessmentError'}), 'Test 5 Failed: Unreadable file must fail-closed');
fprintf('  [PASS] Test 5: Missing/unreadable file failed closed (Decision: %s)\n', dec5);
testsPassed = testsPassed + 1;

% Test 6: Thrown exception / corrupt input data type
testsRun = testsRun + 1;
corruptInput = {'corrupted', struct('invalid', true)};
[dec6, ~, msg6] = assess_image_quality(corruptInput);
assert(ismember(dec6, {'Ungradable', 'AssessmentError'}), 'Test 6 Failed: Thrown exception must fail-closed');
assert(~isempty(msg6), 'Test 6 Failed: Recapture/error message must be provided on failure');
fprintf('  [PASS] Test 6: Corrupted input safely failed closed (Decision: %s, Message: "%s")\n', dec6, msg6);
testsPassed = testsPassed + 1;

results.testsRun = testsRun;
results.testsPassed = testsPassed;
results.allPassed = (testsRun == testsPassed);

end
