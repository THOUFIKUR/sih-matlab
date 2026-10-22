function caseData = fetch_case_from_supabase(caseCode)
% FETCH_CASE_FROM_SUPABASE Queries Supabase for patient records & clinician reviews.
% Pure MATLAB function with ZERO UI dependencies.
%
% Syntax:
%   caseData = fetch_case_from_supabase('RS-2026-001')
%
% Output:
%   caseData: Struct containing patient demographics, encounters, and doctor sign-offs.

cfg = supabase_config();

if nargin < 1 || isempty(caseCode)
    error('Please specify a Case ID string, e.g. ''RS-2026-001''.');
end

payload = struct('p_case_code', char(caseCode));

options = weboptions(...
    'HeaderFields', {
        'apikey',        cfg.anon_key;
        'Authorization', ['Bearer ', cfg.anon_key];
        'Content-Type',  'application/json'
    }, ...
    'MediaType', 'application/json', ...
    'Timeout', cfg.timeout);

fprintf('[SUPABASE] Fetching Case %s from cloud project %s...\n', char(caseCode), cfg.project_ref);

try
    rawResp = webwrite(cfg.rpc_fetch_url, payload, options);
    if ischar(rawResp) || isstring(rawResp)
        caseData = jsondecode(rawResp);
    else
        caseData = rawResp;
    end
    if isempty(caseData) || (isstruct(caseData) && isempty(fieldnames(caseData)))
        fprintf('  [NOTICE] Case %s not found in remote Supabase database.\n', char(caseCode));
    else
        fprintf('  [FOUND] Patient: %s (Age %d, Sex %s)\n', ...
            caseData.full_name, caseData.age, caseData.sex);
    end
catch ME
    fprintf('  [ERROR] Fetch failed: %s\n', ME.message);
    caseData = struct('status', 'error', 'message', ME.message);
end

end
