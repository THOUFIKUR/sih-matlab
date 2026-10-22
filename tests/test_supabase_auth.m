% TEST_SUPABASE_AUTH Test doctor auth and queue services
addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

fprintf('=== TESTING SUPABASE AUTH & TELE-REVIEW QUEUE ===\n');

% 1. Test Password Recovery
[recOk, recMsg] = SupabaseAuth.recoverPassword('doctor.sih@retinascan.ai');
assert(recOk, sprintf('Password recovery failed: %s', recMsg));
fprintf('[PASS] Password recovery request sent: %s\n', recMsg);

% 2. Test Doctor Login
[logOk, logSess, logProf] = SupabaseAuth.login('doctor.sih@retinascan.ai', 'DoctorSecurePass2026!');
assert(logOk, 'Doctor login failed');
fprintf('[PASS] Doctor login succeeded for: %s (Doctor ID: %s)\n', ...
    logProf.full_name, logProf.doctor_code);

% 3. Test Tele-Review Queue Fetch
q = SupabaseAuth.fetchTeleReviewQueue();
assert(iscell(q) || isstruct(q), 'Queue fetch returned invalid type');
fprintf('[PASS] Tele-Review Queue fetched successfully (%d cases)\n', numel(q));

fprintf('\n>>> ALL SUPABASE AUTH & QUEUE TESTS PASSED! <<<\n');
