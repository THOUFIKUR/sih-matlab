classdef SupabaseAuth
    % SUPABASEAUTH Pure MATLAB service for doctor authentication, password recovery,
    % tele-review queue querying, and clinical review submissions via Supabase.
    
    methods (Static)
        function [success, sessionOrErr, profile] = login(email, password)
            % Doctor Sign In with Email & Password (Direct RPC with fallback)
            cfg = supabase_config();
            success = false;
            sessionOrErr = '';
            profile = struct();
            
            cleanEmail = strtrim(char(email));
            cleanPass  = char(password);
            
            % 1. Try High-Reliability Direct Database Authentication
            payload = struct('p_email', cleanEmail, 'p_password', cleanPass);
            options = weboptions('HeaderFields', {
                'apikey',        cfg.anon_key;
                'Authorization', ['Bearer ', cfg.anon_key];
                'Content-Type',  'application/json'
            }, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            
            try
                raw = webwrite(cfg.rpc_login_url, payload, options);
                if ischar(raw) || isstring(raw), resp = jsondecode(raw); else, resp = raw; end
                
                if isfield(resp, 'status') && strcmp(resp.status, 'success')
                    success = true;
                    profile = resp;
                    sessionOrErr = struct('access_token', 'local_jwt', 'user', struct('id', resp.doctor_id, 'email', resp.email));
                    return;
                elseif isfield(resp, 'status') && strcmp(resp.status, 'error')
                    sessionOrErr = resp.message;
                    return;
                end
            catch
                % Fall back to standard GoTrue endpoint if RPC is unavailable
            end
            
            % 2. Standard GoTrue Token Endpoint Fallback
            headers = {
                'apikey',        cfg.anon_key;
                'Content-Type',  'application/json'
            };
            opt = weboptions('HeaderFields', headers, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            fbPayload = struct('email', cleanEmail, 'password', cleanPass);
            
            try
                raw = webwrite(cfg.auth_token_url, fbPayload, opt);
                if ischar(raw) || isstring(raw), resp = jsondecode(raw); else, resp = raw; end
                
                success = true;
                sessionOrErr = resp;
                userId = resp.user.id;
                profile = SupabaseAuth.fetchDoctorProfile(userId, resp.access_token);
            catch ME
                sessionOrErr = ME.message;
            end
        end
        
        function [success, msg, userId] = signup(email, password, doctorData)
            % Doctor Registration with Direct Pre-Confirmation (No 429 Rate Limits)
            cfg = supabase_config();
            success = false;
            msg = '';
            userId = '';
            
            dName     = SupabaseAuth.getFieldSafe(doctorData, 'full_name', 'Doctor');
            dCode     = SupabaseAuth.getFieldSafe(doctorData, 'doctor_code', 'MCI-PENDING');
            dSpec     = SupabaseAuth.getFieldSafe(doctorData, 'specialty', 'Ophthalmology');
            dYears    = int32(SupabaseAuth.getFieldSafe(doctorData, 'years_experience', 5));
            dHospital = SupabaseAuth.getFieldSafe(doctorData, 'hospital', 'Base Eye Hospital');
            dPhone    = SupabaseAuth.getFieldSafe(doctorData, 'phone', '');
            
            payload = struct(...
                'p_email',       strtrim(char(email)), ...
                'p_password',    char(password), ...
                'p_full_name',   dName, ...
                'p_doctor_code', dCode, ...
                'p_specialty',   dSpec, ...
                'p_years',       dYears, ...
                'p_hospital',    dHospital, ...
                'p_phone',       dPhone ...
            );
            
            options = weboptions('HeaderFields', {
                'apikey',        cfg.anon_key;
                'Authorization', ['Bearer ', cfg.anon_key];
                'Content-Type',  'application/json'
            }, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            
            try
                raw = webwrite(cfg.rpc_register_url, payload, options);
                if ischar(raw) || isstring(raw), resp = jsondecode(raw); else, resp = raw; end
                
                if isfield(resp, 'status') && strcmp(resp.status, 'success')
                    success = true;
                    msg = sprintf('Doctor account registered and activated for %s! You can now sign in immediately.', resp.email);
                    if isfield(resp, 'user_id'), userId = resp.user_id; end
                else
                    msg = resp.message;
                end
            catch ME
                msg = ME.message;
            end
        end
        
        function [success, msg] = resetPasswordDirect(email, newPassword)
            % Direct In-App Password Reset (Bypasses email delivery delays)
            cfg = supabase_config();
            success = false;
            
            payload = struct(...
                'p_email',        strtrim(char(email)), ...
                'p_new_password', char(newPassword) ...
            );
            
            options = weboptions('HeaderFields', {
                'apikey',        cfg.anon_key;
                'Authorization', ['Bearer ', cfg.anon_key];
                'Content-Type',  'application/json'
            }, 'MediaType', 'application/json', 'Timeout', cfg.timeout);
            
            try
                raw = webwrite(cfg.rpc_reset_pw_url, payload, options);
                if ischar(raw) || isstring(raw), resp = jsondecode(raw); else, resp = raw; end
                
                if isfield(resp, 'status') && strcmp(resp.status, 'success')
                    success = true;
                    msg = resp.message;
                else
                    msg = resp.message;
                end
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
                msg = sprintf('Password recovery link dispatched to %s. Please check your inbox and Spam folder.', char(email));
            catch ME
                if contains(ME.message, '429') || contains(ME.message, 'Too Many Requests')
                    success = true;
                    msg = sprintf(['Recovery link request received for %s.\n\n', ...
                        'Note: Free tier SMTP has a 3-email/hr rate limit. ', ...
                        'If email is not received, use the "Instant Password Reset" tab to reset immediately.'], char(email));
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
                    decoded = jsondecode(raw);
                else
                    decoded = raw;
                end
                
                % Guarantee queue is ALWAYS returned as a cell array
                if isstruct(decoded)
                    queue = num2cell(decoded);
                elseif iscell(decoded)
                    queue = decoded;
                else
                    queue = {};
                end
            catch ME
                fprintf('[SUPABASE QUEUE ERROR] %s\n', ME.message);
                queue = {};
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
