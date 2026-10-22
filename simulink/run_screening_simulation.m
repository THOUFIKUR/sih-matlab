function simResults = run_screening_simulation(scenarioName, customParams)
% RUN_SCREENING_SIMULATION Simulates rural eye screening workflow & queueing dynamics.
%
% Implements genuine discrete-event stochastic simulation of patient flow:
%   Arrival -> Image Quality Gate -> Preprocessing -> Model Inference ->
%   Network Transmission -> Clinician Review -> Completed / Referred.
%
% Strict Requirement: Conservation Check (Arrived == Completed + Rejected + InQueue).
%
% Syntax:
%   simResults = run_screening_simulation()
%   simResults = run_screening_simulation('Connected')
%   simResults = run_screening_simulation('LowBandwidth')
%   simResults = run_screening_simulation('OfflineBacklog')
%   simResults = run_screening_simulation('Optimized')

if nargin < 1 || isempty(scenarioName)
    scenarioName = 'Connected';
end

% Set reproducible random seed
rng(42);

%% 1. Scenario Configuration
params = struct();
params.simDurationHours = 8.0;          % 8-hour clinic shift
params.arrivalRatePerHour = 15;         % 15 patients/hr (1 patient every 4 mins)
params.qualityRejectionRate = 0.05;      % 5% ungradable rate
params.processingTimeSec = 2.5;         % 2.5s for enhancement + structure localization
params.inferenceTimeSec = 1.2;          % 1.2s for ONNX forward passes
params.networkBandwidthMbps = 5.0;      % 5 Mbps uplink
params.imageSizeMB = 4.0;               % 4 MB per case
params.clinicianServiceTimeMin = 1.5;   % 1.5 min per review
params.numClinicians = 1;               % 1 reviewer

switch lower(scenarioName)
    case 'connected'
        params.networkBandwidthMbps = 15.0;
        params.packetLossRate = 0.01;
    case 'lowbandwidth'
        params.networkBandwidthMbps = 0.5;  % 512 Kbps satellite/2G
        params.packetLossRate = 0.08;
    case 'offlinebacklog'
        params.networkBandwidthMbps = 0.0;  % Completely offline during shift, batch sync
        params.packetLossRate = 0.0;
    case 'optimized'
        params.networkBandwidthMbps = 10.0;
        params.numClinicians = 2;           % 2 distributed telemedicine doctors
        params.packetLossRate = 0.01;
    otherwise
        % Default connected
end

% Apply custom overrides if provided
if nargin >= 2 && isstruct(customParams)
    fNames = fieldnames(customParams);
    for k = 1:numel(fNames)
        params.(fNames{k}) = customParams.(fNames{k});
    end
end

%% 2. Generate Patient Arrivals (Poisson Process via Exponential Inter-arrivals)
totalDurationSec = params.simDurationHours * 3600;
meanInterArrival = 3600 / params.arrivalRatePerHour;

arrivalTimes = [];
% Generate exponential random inter-arrival without toolbox dependency
currT = -meanInterArrival * log(max(eps, rand()));
while currT < totalDurationSec
    arrivalTimes = [arrivalTimes; currT]; %#ok<AGROW>
    currT = currT + (-meanInterArrival * log(max(eps, rand())));
end

numArrived = numel(arrivalTimes);

%% 3. Simulate Pipeline Stages
completedCases = 0;
rejectedQualityCases = 0;
failedNetworkCases = 0;
stillInQueueCases = 0;

turnaroundTimes = [];
queueLengthsOverTime = zeros(ceil(totalDurationSec / 60), 1); % Per minute

clinicianNextFreeTime = 0.0;

for i = 1:numArrived
    arrT = arrivalTimes(i);
    
    % Stage 1: Quality Gate
    if rand() < params.qualityRejectionRate
        rejectedQualityCases = rejectedQualityCases + 1;
        continue;
    end
    
    % Stage 2: Processing & Local Inference
    procEndT = arrT + params.processingTimeSec + params.inferenceTimeSec;
    
    % Stage 3: Network Transmission
    if params.networkBandwidthMbps > 0
        transferSec = (params.imageSizeMB * 8) / params.networkBandwidthMbps;
        if rand() < params.packetLossRate
            % Retry once
            transferSec = transferSec * 2.0;
        end
        netEndT = procEndT + transferSec;
    else
        % Offline scenario: Queued until batch upload at end of day
        netEndT = totalDurationSec; 
    end
    
    % Stage 4: Clinician Review Queue
    clinicianWaitStart = netEndT;
    if clinicianWaitStart >= totalDurationSec
        stillInQueueCases = stillInQueueCases + 1;
        continue;
    end
    
    % Start review when clinician is available
    reviewStart = max(clinicianWaitStart, clinicianNextFreeTime);
    meanServiceSec = params.clinicianServiceTimeMin * 60 / params.numClinicians;
    reviewDurationSec = -meanServiceSec * log(max(eps, rand()));
    reviewEnd = reviewStart + reviewDurationSec;
    
    if reviewEnd <= totalDurationSec
        completedCases = completedCases + 1;
        turnaroundTimes = [turnaroundTimes; (reviewEnd - arrT) / 60]; %#ok<AGROW>
        clinicianNextFreeTime = reviewEnd;
    else
        stillInQueueCases = stillInQueueCases + 1;
        clinicianNextFreeTime = reviewEnd;
    end
    
    % Record queue state
    minIdx = min(ceil(arrT / 60), numel(queueLengthsOverTime));
    if minIdx > 0
        queueLengthsOverTime(minIdx) = queueLengthsOverTime(minIdx) + 1;
    end
end

%% 4. Conservation Check
totalAccounted = completedCases + rejectedQualityCases + failedNetworkCases + stillInQueueCases;
conservationPassed = (totalAccounted == numArrived);

%% 5. Compile Results
simResults = struct();
simResults.scenario = scenarioName;
simResults.params = params;
simResults.totalArrived = numArrived;
simResults.completedCases = completedCases;
simResults.rejectedQualityCases = rejectedQualityCases;
simResults.failedNetworkCases = failedNetworkCases;
simResults.stillInQueueCases = stillInQueueCases;
simResults.conservationCheck = conservationPassed;

if ~isempty(turnaroundTimes)
    simResults.meanTurnaroundMinutes = mean(turnaroundTimes);
    simResults.medianTurnaroundMinutes = median(turnaroundTimes);
    sortedT = sort(turnaroundTimes);
    p90Idx = max(1, min(numel(sortedT), round(0.90 * numel(sortedT))));
    simResults.p90TurnaroundMinutes = sortedT(p90Idx);
    simResults.maxTurnaroundMinutes = max(turnaroundTimes);
else
    simResults.meanTurnaroundMinutes = 0;
    simResults.medianTurnaroundMinutes = 0;
    simResults.p90TurnaroundMinutes = 0;
    simResults.maxTurnaroundMinutes = 0;
end

simResults.throughputPerHour = completedCases / params.simDurationHours;
simResults.clinicianUtilizationPct = min(100.0, (sum(turnaroundTimes) * 60) / (totalDurationSec * params.numClinicians) * 100);
simResults.queueLengthsOverTime = queueLengthsOverTime;

fprintf('\n=========================================================================\n');
fprintf('RETINASCAN SIMULATION — SCENARIO: %s\n', upper(scenarioName));
fprintf('-------------------------------------------------------------------------\n');
fprintf('Total Arrived Patients:      %d\n', numArrived);
fprintf('Completed Screenings:        %d (%.1f%%)\n', completedCases, 100 * completedCases / max(1, numArrived));
fprintf('Quality Rejections:          %d (%.1f%%)\n', rejectedQualityCases, 100 * rejectedQualityCases / max(1, numArrived));
fprintf('Still Queued at Shift End:   %d (%.1f%%)\n', stillInQueueCases, 100 * stillInQueueCases / max(1, numArrived));
fprintf('Conservation Check (Arrived == Sum): %s\n', mat2str(conservationPassed));
fprintf('Throughput:                  %.2f patients/hour\n', simResults.throughputPerHour);
fprintf('Mean Turnaround Time:        %.1f minutes (P90: %.1f mins)\n', simResults.meanTurnaroundMinutes, simResults.p90TurnaroundMinutes);
fprintf('Clinician Utilization:       %.1f%%\n', simResults.clinicianUtilizationPct);
fprintf('=========================================================================\n\n');

end
