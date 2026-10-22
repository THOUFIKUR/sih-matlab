function result = sync_case_to_supabase(caseInput)
% SYNC_CASE_TO_SUPABASE Syncs patient cases and AI findings directly to Supabase.
% Headless, pure MATLAB implementation with ZERO UI dependencies.
%
% Syntax:
%   result = sync_case_to_supabase()                  % Syncs all local cases
%   result = sync_case_to_supabase('RS-2026-001')     % Syncs specific Case ID
%   result = sync_case_to_supabase(caseDataStruct)    % Syncs struct directly
%
% Output:
%   result: Struct with sync status, patient_id, encounter_id, and timestamp.

cfg = supabase_config();

% 1. Determine Input Type
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
casesDir = fullfile(projectRoot, 'data', 'cases');

if nargin < 1 || isempty(caseInput)
    % Batch sync all local cases
    caseFiles = dir(fullfile(casesDir, 'RS-*.mat'));
    if isempty(caseFiles)
        fprintf('[SUPABASE] No local case files found in %s\n', casesDir);
        result = struct('status', 'empty', 'synced_count', 0);
        return;
    end
    fprintf('[SUPABASE] Starting batch sync of %d local cases to cloud...\n', numel(caseFiles));
    synced = 0;
    for k = 1:numel(caseFiles)
        fPath = fullfile(casesDir, caseFiles(k).name);
        try
            subRes = sync_case_to_supabase(fPath);
            if isfield(subRes, 'status') && strcmp(subRes.status, 'success')
                synced = synced + 1;
            end
        catch ME
            fprintf('  [WARN] Failed to sync %s: %s\n', caseFiles(k).name, ME.message);
        end
    end
    result = struct('status', 'success', 'synced_count', synced, 'total_files', numel(caseFiles));
    fprintf('[SUPABASE] Batch sync completed: %d/%d cases synchronized.\n', synced, numel(caseFiles));
    return;
end

% Handle Case ID string or file path
if ischar(caseInput) || isstring(caseInput)
    caseStr = char(caseInput);
    if isfile(caseStr)
        matFile = caseStr;
    else
        % Treat as Case ID
        matFile = fullfile(casesDir, [caseStr, '.mat']);
        if ~isfile(matFile)
            matFile = fullfile(casesDir, sprintf('RS-%s.mat', caseStr));
        end
    end
    
    if ~isfile(matFile)
        error('Case file not found: %s', caseStr);
    end
    
    loaded = load(matFile);
    if isfield(loaded, 'caseData')
        c = loaded.caseData;
    else
        c = loaded;
    end
elseif isstruct(caseInput)
    c = caseInput;
else
    error('Unsupported input type. Provide case ID string or struct.');
end

% 2. Extract Data Fields safely with sensible defaults
caseCode = getFieldSafe(c, 'CaseID', 'RS-UNKNOWN');
fullName = getFieldSafe(c, 'PatientName', 'Anonymous Patient');
age      = int32(getFieldSafe(c, 'PatientAge', 50));
sex      = getFieldSafe(c, 'PatientGender', 'Other');
phone    = getFieldSafe(c, 'Contact', '');
insId    = getFieldSafe(c, 'InsuranceID', '');
village  = getFieldSafe(c, 'Village', 'Rural Camp');
district = getFieldSafe(c, 'District', 'Rural');
diabYrs  = getFieldSafe(c, 'DiabetesYears', 5.0);
hba1c    = getFieldSafe(c, 'HbA1c', 7.0);

% AI Results extraction
odGrade = 0;
odRef   = false;
if isfield(c, 'ClassificationOD') && isstruct(c.ClassificationOD)
    odGrade = int32(getFieldSafe(c.ClassificationOD, 'predicted_grade', 0));
    odRef   = logical(getFieldSafe(c.ClassificationOD, 'is_referable', false));
end

osGrade = 0;
osRef   = false;
if isfield(c, 'ClassificationOS') && isstruct(c.ClassificationOS)
    osGrade = int32(getFieldSafe(c.ClassificationOS, 'predicted_grade', 0));
    osRef   = logical(getFieldSafe(c.ClassificationOS, 'is_referable', false));
end

% Lesion summaries extraction
odLesions = struct();
if isfield(c, 'DetectionsOD') && istable(c.DetectionsOD) && height(c.DetectionsOD) > 0
    uClasses = unique(c.DetectionsOD.ClassName);
    for u = 1:numel(uClasses)
        cName = regexprep(uClasses{u}, '[^a-zA-Z0-9]', '_');
        odLesions.(cName) = sum(strcmp(c.DetectionsOD.ClassName, uClasses{u}));
    end
end

osLesions = struct();
if isfield(c, 'DetectionsOS') && istable(c.DetectionsOS) && height(c.DetectionsOS) > 0
    uClasses = unique(c.DetectionsOS.ClassName);
    for u = 1:numel(uClasses)
        cName = regexprep(uClasses{u}, '[^a-zA-Z0-9]', '_');
        osLesions.(cName) = sum(strcmp(c.DetectionsOS.ClassName, uClasses{u}));
    end
end

doctorNotes = getFieldSafe(c, 'ClinicalNotes', '');
if iscell(doctorNotes), doctorNotes = strjoin(doctorNotes, ' '); end

% 3. Assemble JSON Payload for Supabase RPC
payload = struct();
payload.p_case_code      = caseCode;
payload.p_full_name      = fullName;
payload.p_age            = age;
payload.p_sex            = sex;
payload.p_phone          = phone;
payload.p_insurance_id   = insId;
payload.p_village        = village;
payload.p_district       = district;
payload.p_diabetes_years = diabYrs;
payload.p_hba1c          = hba1c;
payload.p_od_grade       = odGrade;
payload.p_os_grade       = osGrade;
payload.p_od_referable   = odRef;
payload.p_os_referable   = osRef;
payload.p_od_lesions     = odLesions;
payload.p_os_lesions     = osLesions;
payload.p_doctor_notes   = doctorNotes;

% 4. HTTP Headers with Supabase API Key
options = weboptions(...
    'HeaderFields', {
        'apikey',        cfg.anon_key;
        'Authorization', ['Bearer ', cfg.anon_key];
        'Content-Type',  'application/json';
        'Prefer',        'return=representation'
    }, ...
    'MediaType', 'application/json', ...
    'Timeout', cfg.timeout);

% 5. Send POST Request to Supabase RPC
fprintf('[SUPABASE] Syncing Case %s (%s, Age %d) to %s...\n', ...
    caseCode, fullName, age, cfg.project_ref);

try
    rawResp = webwrite(cfg.rpc_sync_url, payload, options);
    if ischar(rawResp) || isstring(rawResp)
        result = jsondecode(rawResp);
    else
        result = rawResp;
    end
    fprintf('  [SUCCESS] Cloud sync confirmed! Patient ID: %s | Encounter: %s | Priority: %s\n', ...
        result.patient_id, result.encounter_id, result.priority);
catch ME
    fprintf('  [ERROR] Supabase sync failed: %s\n', ME.message);
    result = struct('status', 'error', 'message', ME.message, 'case_code', caseCode);
end

end

% Helper function for safe struct field access
function val = getFieldSafe(s, fieldName, defaultVal)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end
