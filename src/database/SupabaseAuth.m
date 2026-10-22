classdef SupabaseAuth
    % SUPABASEAUTH Pure MATLAB service for doctor authentication, password recovery,
    % tele-review queue querying, and clinical review submissions via Supabase.
    
    methods (Static)
        function [success, sessionOrErr, profile] = login(email, password)
            % Doctor Sign In with Email & Password
            cfg = supabase_config();
            success = false;
            sessionOrErr = '';
            profile = struct();
            
            headers = {
                'apikey',        cfg.anon_key;
                'Content-Type',  'application/json'
            };
            options = weboptions('HeaderFields', headers, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            payload = struct('email', strtrim(char(email)), 'password', char(password));
            
            try
                raw = webwrite(cfg.auth_token_url, payload, options);
                if ischar(raw) || isstring(raw), resp = jsondecode(raw); else, resp = raw; end
                
                success = true;
                sessionOrErr = resp;
                
                % Fetch doctor profile
                userId = resp.user.id;
                profile = SupabaseAuth.fetchDoctorProfile(userId, resp.access_token);
            catch ME
                sessionOrErr = ME.message;
            end
        end
        
        function [success, msg, userId] = signup(email, password, doctorData)
            % Doctor Sign Up with Registration Details
            cfg = supabase_config();
            success = false;
            msg = '';
            userId = '';
            
            headers = {
                'apikey',        cfg.anon_key;
                'Content-Type',  'application/json'
            };
            options = weboptions('HeaderFields', headers, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            
            payload = struct();
            payload.email = strtrim(char(email));
            payload.password = char(password);
            
            try
                raw = webwrite(cfg.auth_signup_url, payload, options);
                if ischar(raw) || isstring(raw), resp = jsondecode(raw); else, resp = raw; end
                
                if isfield(resp, 'id')
                    userId = resp.id;
                elseif isfield(resp, 'user') && isfield(resp.user, 'id')
                    userId = resp.user.id;
                end
                
                % Upsert Doctor Profile in public.profiles
                if ~isempty(userId)
                    dName     = SupabaseAuth.getFieldSafe(doctorData, 'full_name', 'Doctor');
                    dCode     = SupabaseAuth.getFieldSafe(doctorData, 'doctor_code', 'MCI-PENDING');
                    dSpec     = SupabaseAuth.getFieldSafe(doctorData, 'specialty', 'Ophthalmology');
                    dYears    = int32(SupabaseAuth.getFieldSafe(doctorData, 'years_experience', 5));
                    dHospital = SupabaseAuth.getFieldSafe(doctorData, 'hospital', 'Base Eye Hospital');
                    dPhone    = SupabaseAuth.getFieldSafe(doctorData, 'phone', '');
                    
                    profilePayload = struct(...
                        'p_user_id',     userId, ...
                        'p_full_name',   dName, ...
                        'p_doctor_code', dCode, ...
                        'p_specialty',   dSpec, ...
                        'p_years',       dYears, ...
                        'p_hospital',    dHospital, ...
                        'p_phone',       dPhone ...
                    );
                    
                    rpcOpt = weboptions('HeaderFields', {
                        'apikey',        cfg.anon_key;
                        'Authorization', ['Bearer ', cfg.anon_key];
                        'Content-Type',  'application/json'
                    }, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
                    
                    webwrite(cfg.rpc_profile_url, profilePayload, rpcOpt);
                end
                
                success = true;
                msg = 'Registration successful! Doctor profile created.';
            catch ME
                msg = ME.message;
            end
        end
        
        function [success, msg] = recoverPassword(email)
            % Send Password Reset Link to Doctor's Email Address
            cfg = supabase_config();
            success = false;
            
            headers = {
                'apikey',        cfg.anon_key;
                'Content-Type',  'application/json'
            };
            options = weboptions('HeaderFields', headers, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            payload = struct('email', strtrim(char(email)));
            
            try
                webwrite(cfg.auth_recover_url, payload, options);
                success = true;
                msg = sprintf('Password recovery link sent to %s. Please check your inbox.', char(email));
            catch ME
                if contains(ME.message, '429') || contains(ME.message, 'Too Many Requests')
                    success = true;
                    msg = sprintf('Recovery link triggered for %s (Rate-limited on test SMTP; please check your inbox or wait 60s).', char(email));
                else
                    msg = ME.message;
                end
            end
        end
        
        function queue = fetchTeleReviewQueue()
            % Fetch all rural camp patient screening encounters
            cfg = supabase_config();
            queue = {};
            
            options = weboptions('HeaderFields', {
                'apikey',        cfg.anon_key;
                'Authorization', ['Bearer ', cfg.anon_key];
                'Content-Type',  'application/json'
            }, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            
            try
                raw = webwrite(cfg.rpc_queue_url, struct(), options);
                if ischar(raw) || isstring(raw)
                    queue = jsondecode(raw);
                else
                    queue = raw;
                end
            catch ME
                fprintf('[SUPABASE QUEUE ERROR] %s\n', ME.message);
            end
        end
        
        function [success, res] = submitDoctorReview(caseCode, doctorId, doctorName, decision, odGrade, osGrade, urgency, facility, notes)
            % Submit verified review to Supabase
            cfg = supabase_config();
            success = false;
            res = struct();
            
            payload = struct(...
                'p_case_code',           char(caseCode), ...
                'p_doctor_id',           char(doctorId), ...
                'p_doctor_name',         char(doctorName), ...
                'p_decision',            char(decision), ...
                'p_confirmed_grade_od',  int32(odGrade), ...
                'p_confirmed_grade_os',  int32(osGrade), ...
                'p_referral_urgency',    char(urgency), ...
                'p_referral_facility',   char(facility), ...
                'p_notes',               char(notes) ...
            );
            
            options = weboptions('HeaderFields', {
                'apikey',        cfg.anon_key;
                'Authorization', ['Bearer ', cfg.anon_key];
                'Content-Type',  'application/json'
            }, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            
            try
                raw = webwrite(cfg.rpc_review_url, payload, options);
                if ischar(raw) || isstring(raw)
                    res = jsondecode(raw);
                else
                    res = raw;
                end
                if isfield(res, 'status') && strcmp(res.status, 'success')
                    success = true;
                end
            catch ME
                res = struct('status', 'error', 'message', ME.message);
            end
        end
        
        function profile = fetchDoctorProfile(userId, token)
            % Fetch profile from public.profiles
            cfg = supabase_config();
            profile = struct();
            if nargin < 2, token = cfg.anon_key; end
            
            url = sprintf('%s/profiles?id=eq.%s&select=*', cfg.rest_url, char(userId));
            options = weboptions('HeaderFields', {
                'apikey',        cfg.anon_key;
                'Authorization', ['Bearer ', token]
            }, 'Timeout', cfg.timeout);
            
            try
                raw = webread(url, options);
                if ischar(raw) || isstring(raw), resp = jsondecode(raw); else, resp = raw; end
                if iscell(resp) && ~isempty(resp)
                    profile = resp{1};
                elseif isstruct(resp) && ~isempty(resp)
                    profile = resp;
                end
            catch
            end
        end
        
        function val = getFieldSafe(s, fieldName, defaultVal)
            if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
                val = s.(fieldName);
            else
                val = defaultVal;
            end
        end
    end
end
