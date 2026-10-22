function cfg = supabase_config()
% SUPABASE_CONFIG Returns configuration parameters for Supabase cloud sync & Auth.
% SIH 26038 Tele-Ophthalmology Database & Doctor Portal Connection.

cfg = struct();
cfg.project_ref = 'lxzdrtfbpxpiuphfzcyw';
cfg.project_url = 'https://lxzdrtfbpxpiuphfzcyw.supabase.co';

% Supabase API Keys
cfg.anon_key    = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4emRydGZicHhwaXVwaGZ6Y3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0ODcwNDcsImV4cCI6MjEwMzA2MzA0N30.ZqUVsjyMVGRfG3Hu6l-fQUB0qQjuXMS4PiRL83p91lw';
cfg.publishable = 'sb_publishable_5JAGGapsZHdhYcCbwhKozQ_8I5RQQuu';

% Auth Endpoints
cfg.auth_token_url   = [cfg.project_url, '/auth/v1/token?grant_type=password'];
cfg.auth_signup_url  = [cfg.project_url, '/auth/v1/signup'];
cfg.auth_recover_url = [cfg.project_url, '/auth/v1/recover'];

% RPC Data Endpoints
cfg.rpc_sync_url     = [cfg.project_url, '/rest/v1/rpc/matlab_sync_case'];
cfg.rpc_fetch_url    = [cfg.project_url, '/rest/v1/rpc/matlab_fetch_case'];
cfg.rpc_queue_url    = [cfg.project_url, '/rest/v1/rpc/matlab_get_tele_review_queue'];
cfg.rpc_review_url   = [cfg.project_url, '/rest/v1/rpc/matlab_submit_doctor_review'];
cfg.rpc_profile_url  = [cfg.project_url, '/rest/v1/rpc/matlab_upsert_doctor_profile'];
cfg.rest_url         = [cfg.project_url, '/rest/v1'];

% Timeout in seconds
cfg.timeout = 15;
end
