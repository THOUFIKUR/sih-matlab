% TEST_SUPABASE_SYNC Smoke test for headless MATLAB to Supabase sync.
addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

fprintf('=== TESTING HEADLESS SUPABASE SYNC (SIH 26038) ===\n');

% 1. Test single case sync
res1 = sync_case_to_supabase('RS-2026-001');
assert(strcmp(res1.status, 'success'), 'Failed to sync RS-2026-001');

% 2. Test fetch case from Supabase
cData = fetch_case_from_supabase('RS-2026-001');
assert(~isempty(cData.full_name), 'Failed to fetch patient full_name');
fprintf('Verified fetched patient: %s\n', cData.full_name);

% 3. Test direct struct sync
customCase = struct();
customCase.CaseID = 'RS-DEMO-999';
customCase.PatientName = 'Lakshmi Narayanan';
customCase.PatientAge = 62;
customCase.PatientGender = 'Female';
customCase.Contact = '+91-9876543210';
customCase.Village = 'Thanjavur Camp';
customCase.District = 'Thanjavur';
customCase.DiabetesYears = 12.0;
customCase.HbA1c = 9.2;
customCase.ClassificationOD = struct('predicted_grade', 3, 'is_referable', true);
customCase.ClassificationOS = struct('predicted_grade', 2, 'is_referable', true);
customCase.ClinicalNotes = 'Urgent vitreo-retina consultation required within 1 week.';

res2 = sync_case_to_supabase(customCase);
assert(strcmp(res2.status, 'success'), 'Failed to sync custom case');

fprintf('\n>>> ALL SUPABASE TESTS PASSED! Headless MATLAB sync is 100%% operational! <<<\n');
