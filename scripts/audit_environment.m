%% audit_environment.m
% Exhaustive audit of MATLAB environment, toolboxes, add-ons, functions,
% GPU, and support packages for SIH 26038 RetinaScan MATLAB project.
%
% Generates output in outputs/audit/environment_audit_report.txt

clc;
clear;

% Ensure all installed toolboxes and support packages are in the active path
restoredefaultpath;
rehash toolboxcache;
savepath;


outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs', 'audit');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
logFile = fullfile(outDir, 'environment_audit_report.txt');
fid = fopen(logFile, 'w');

function logmsg(fid, msg)
    fprintf('%s\n', msg);
    if fid > 0
        fprintf(fid, '%s\r\n', msg);
    end
end

logmsg(fid, '========================================================================');
logmsg(fid, '              RETINASCAN MATLAB SIH 26038 ENVIRONMENT AUDIT           ');
logmsg(fid, ['Timestamp: ' datestr(now, 'yyyy-mm-dd HH:MM:SS')]);
logmsg(fid, '========================================================================');
logmsg(fid, '');

%% 1. Basic System & MATLAB Info
v = ver('MATLAB');
logmsg(fid, '------------------------------------------------------------------------');
logmsg(fid, '1. MATLAB & SYSTEM INFORMATION');
logmsg(fid, '------------------------------------------------------------------------');
if ~isempty(v)
    logmsg(fid, sprintf('MATLAB Release: %s (%s)', v.Release, v.Version));
    logmsg(fid, sprintf('MATLAB Date:    %s', v.Date));
else
    logmsg(fid, 'MATLAB Version info unavailable.');
end
logmsg(fid, sprintf('Computer/Arch:  %s', computer('arch')));
logmsg(fid, sprintf('Root Folder:    %s', matlabroot));
logmsg(fid, sprintf('Current Folder: %s', pwd));
logmsg(fid, '');

%% 2. Installed Products (from ver)
logmsg(fid, '------------------------------------------------------------------------');
logmsg(fid, '2. INSTALLED PRODUCTS (from ver)');
logmsg(fid, '------------------------------------------------------------------------');
allProds = ver;
prodNames = {allProds.Name};
for i = 1:numel(allProds)
    logmsg(fid, sprintf(' - %-45s | Version: %-8s | Release: %s', allProds(i).Name, allProds(i).Version, allProds(i).Release));
end
logmsg(fid, '');

%% 3. Mandatory Products Checklist
logmsg(fid, '------------------------------------------------------------------------');
logmsg(fid, '3. MANDATORY PRODUCTS STATUS (INSTALLED / MISSING)');
logmsg(fid, '------------------------------------------------------------------------');
mandatoryList = {
    'Image Processing Toolbox', 'Image Processing Toolbox';
    'Computer Vision Toolbox', 'Computer Vision Toolbox';
    'Deep Learning Toolbox', 'Deep Learning Toolbox';
    'Statistics and Machine Learning Toolbox', 'Statistics and Machine Learning Toolbox';
    'Simulink', 'Simulink';
    'SimEvents', 'SimEvents';
    'Parallel Computing Toolbox', 'Parallel Computing Toolbox'
};

for i = 1:size(mandatoryList, 1)
    name = mandatoryList{i, 1};
    installed = any(strcmpi(prodNames, name));
    statusStr = 'MISSING';
    if installed
        statusStr = 'INSTALLED';
    end
    logmsg(fid, sprintf(' [%-9s] %s', statusStr, name));
end
logmsg(fid, '');

%% 4. GPU Availability
logmsg(fid, '------------------------------------------------------------------------');
logmsg(fid, '4. GPU AVAILABILITY');
logmsg(fid, '------------------------------------------------------------------------');
gpuCount = 0;
try
    gpuCount = gpuDeviceCount;
    logmsg(fid, sprintf('GPU Device Count: %d', gpuCount));
    if gpuCount > 0
        dev = gpuDevice;
        logmsg(fid, sprintf('GPU Name:                 %s', dev.Name));
        logmsg(fid, sprintf('GPU Compute Capability:   %s', dev.ComputeCapability));
        logmsg(fid, sprintf('GPU Total Memory:         %.2f GB', dev.TotalMemory / (1024^3)));
        logmsg(fid, sprintf('GPU Available Memory:     %.2f GB', dev.AvailableMemory / (1024^3)));
    else
        logmsg(fid, 'No compatible GPU device found (GPU computing disabled/CPU only).');
    end
catch ME
    logmsg(fid, sprintf('GPU check exception: %s', ME.message));
end
logmsg(fid, '');

%% 5. Installed Add-ons (from matlab.addons.installedAddons)
logmsg(fid, '------------------------------------------------------------------------');
logmsg(fid, '5. INSTALLED ADD-ONS (from matlab.addons.installedAddons)');
logmsg(fid, '------------------------------------------------------------------------');
try
    addonsTable = matlab.addons.installedAddons;
    if isempty(addonsTable)
        logmsg(fid, 'No add-ons returned by matlab.addons.installedAddons.');
    else
        for i = 1:height(addonsTable)
            name = addonsTable.Name{i};
            version = addonsTable.Version{i};
            identifier = addonsTable.Identifier{i};
            logmsg(fid, sprintf(' - %-45s | Version: %-8s | ID: %s', name, version, identifier));
        end
    end
catch ME
    logmsg(fid, sprintf('Error querying installed add-ons: %s', ME.message));
end
logmsg(fid, '');

%% 6. Candidate Function Verification (which -all)
logmsg(fid, '------------------------------------------------------------------------');
logmsg(fid, '6. CANDIDATE FUNCTIONS VERIFICATION (which -all)');
logmsg(fid, '------------------------------------------------------------------------');
functionsToCheck = {
    'imread';
    'imshow';
    'imadjust';
    'adapthisteq';
    'imfilter';
    'entropy';
    'imbinarize';
    'imfindcircles';
    'bwlabel';
    'regionprops';
    'trainnet';
    'trainNetwork';
    'gradCAM';
    'imageLIME';
    'importNetworkFromONNX';
    'importONNXNetwork';
    'resnet50';
    'efficientnetb0';
    'yolov8ObjectDetector'
};

for i = 1:numel(functionsToCheck)
    fn = functionsToCheck{i};
    locs = which(fn, '-all');
    if isempty(locs)
        logmsg(fid, sprintf(' [%-7s] %s', 'MISSING', fn));
    else
        logmsg(fid, sprintf(' [%-7s] %s -> %s', 'FOUND', fn, locs{1}));
        if numel(locs) > 1
            for j = 2:numel(locs)
                logmsg(fid, sprintf('           shadowed: %s', locs{j}));
            end
        end
    end
end
logmsg(fid, '');

%% 7. License Status Verification (Separated from Installation)
logmsg(fid, '------------------------------------------------------------------------');
logmsg(fid, '7. LICENSE CHECK (Separated from Installation)');
logmsg(fid, '------------------------------------------------------------------------');
licensesToCheck = {
    'Image_Toolbox';
    'Video_and_Image_Blockset'; % Computer Vision
    'Neural_Network_Toolbox';   % Deep Learning
    'Statistics_Toolbox';
    'SIMULINK';
    'SimEvents';
    'Distrib_Computing_Toolbox' % Parallel Computing
};

for i = 1:numel(licensesToCheck)
    lic = licensesToCheck{i};
    [status, msg] = license('checkout', lic);
    if status == 1
        logmsg(fid, sprintf(' [CHECKOUT OK] License: %-25s', lic));
    else
        logmsg(fid, sprintf(' [CHECKOUT FAIL] License: %-23s -> %s', lic, msg));
    end
end
logmsg(fid, '');
logmsg(fid, '========================================================================');
logmsg(fid, '                         END OF AUDIT REPORT                            ');
logmsg(fid, '========================================================================');

if fid > 0
    fclose(fid);
end
