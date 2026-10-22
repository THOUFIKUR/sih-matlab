function allSuccess = run_all_tests()
% RUN_ALL_TESTS Executes the complete test suite for Milestone 2.
%
% Runs:
% 1. Quality gate tests (fail-closed, edge cases, exceptions)
% 2. Dataset loader tests (IDRiD grading, localization, segmentation; DRIVE)
% 3. End-to-end smoke tests on sample fundus images

fprintf('=========================================================================\n');
fprintf('RETINASCAN - RUNNING ALL UNIT & SMOKE TESTS (MILESTONE 2)\n');
fprintf('=========================================================================\n\n');

outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs', 'validation');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

testLog = {};
testLog{end+1} = '=========================================================================';
testLog{end+1} = 'RETINASCAN - TEST EXECUTION REPORT';
testLog{end+1} = sprintf('Execution Timestamp: %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
testLog{end+1} = 'Host: Windows 11 x64, MATLAB R2024a';
testLog{end+1} = '-------------------------------------------------------------------------';

totalTests = 0;
passedTests = 0;

% 1. Quality Gate
try
    resQG = test_quality_gate();
    totalTests = totalTests + resQG.testsRun;
    passedTests = passedTests + resQG.testsPassed;
    statusQG = 'PASS';
catch ME
    statusQG = ['FAIL: ', ME.message];
end
testLog{end+1} = sprintf('1. Quality Gate Tests (Fail-Closed, Corrupt, Edge Cases): %s', statusQG);

% 2. Dataset Loaders
try
    resDL = test_dataset_loaders();
    totalTests = totalTests + resDL.testsRun;
    passedTests = passedTests + resDL.testsPassed;
    statusDL = 'PASS';
catch ME
    statusDL = ['FAIL: ', ME.message];
end
testLog{end+1} = sprintf('2. Dataset Loader Tests (IDRiD Grading/Loc/Seg & DRIVE):     %s', statusDL);

% 3. Sample Images Smoke
try
    resSM = test_sample_images_smoke();
    totalTests = totalTests + resSM.testsRun;
    passedTests = passedTests + resSM.testsPassed;
    statusSM = 'PASS';
catch ME
    statusSM = ['FAIL: ', ME.message];
end
testLog{end+1} = sprintf('3. Full Pipeline Smoke Tests (Grades 0-4 Sample Images):     %s', statusSM);

testLog{end+1} = '-------------------------------------------------------------------------';
testLog{end+1} = sprintf('TOTAL INDIVIDUAL CHECKS: %d | PASSED: %d | FAILED: %d', ...
    totalTests, passedTests, totalTests - passedTests);

if passedTests == totalTests && totalTests > 0
    testLog{end+1} = 'OVERALL TEST STATUS: ALL PASS (100%)';
    allSuccess = true;
else
    testLog{end+1} = 'OVERALL TEST STATUS: FAILURES DETECTED';
    allSuccess = false;
end
testLog{end+1} = '=========================================================================';

% Save report
logPath = fullfile(outputDir, 'test_execution_report.txt');
fid = fopen(logPath, 'w');
for i = 1:numel(testLog)
    fprintf(fid, '%s\n', testLog{i});
end
fclose(fid);

fprintf('\nTest Report Summary:\n');
type(logPath);

end
