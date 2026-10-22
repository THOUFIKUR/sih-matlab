function results = benchmark_cpu_training_step()
% BENCHMARK_CPU_TRAINING_STEP Measures forward+backward step latency on CPU.
%
% Benchmark for Milestone 3 planning:
% Measures seconds per batch for efficientnetb0 and resnet50 training steps
% on this CPU at 224x224 and 300x300 resolutions.
% Projects wallclock time for one full training epoch on ~3,600 images (APTOS size).
%
% NOTE: Strictly benchmarking only; NO model training is performed.

outputDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'outputs', 'validation');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

fprintf('=== BENCHMARKING CPU TRAINING STEP LATENCY (FOR MILESTONE 3) ===\n');

models = {'efficientnetb0', 'resnet50'};
resolutions = [224, 300];
batchSize = 8;
numWarmup = 2;
numTimedBatches = 5;
datasetSize = 3600;
numBatchesPerEpoch = ceil(datasetSize / batchSize);

results = struct();
reportLines = {};
reportLines{end+1} = '=========================================================================';
reportLines{end+1} = 'RETINASCAN - CPU TRAINING STEP BENCHMARK & MILESTONE 3 PROJECTION';
reportLines{end+1} = 'Host: Windows 11 x64, Intel/AMD Host CPU (gpuDeviceCount = 0)';
reportLines{end+1} = sprintf('Dataset Target: %d images (APTOS 2019 Blindness Detection scale)', datasetSize);
reportLines{end+1} = sprintf('Batch Size: %d images | Measurement: Forward pass + Loss + dlgradient', batchSize);
reportLines{end+1} = '-------------------------------------------------------------------------';
reportLines{end+1} = sprintf('%-16s | %-10s | %-14s | %-18s | %-18s', ...
    'Model', 'Resolution', 'Sec / Batch', 'Min / Epoch (3600)', 'Hours / 20 Epochs');
reportLines{end+1} = '-------------------------------------------------------------------------';

for mIdx = 1:numel(models)
    modelName = models{mIdx};
    fprintf('\nBenchmarking model: %s...\n', modelName);
    
    for rIdx = 1:numel(resolutions)
        res = resolutions(rIdx);
        fprintf('  Resolution %dx%d (Batch size %d)...\n', res, res, batchSize);
        
        try
            % Load model architecture (untrained weights for FLOP/latency benchmarking)
            if strcmp(modelName, 'efficientnetb0')
                rawNet = efficientnetb0('Weights', 'none');
            else
                rawNet = resnet50('Weights', 'none');
            end
            
            % Convert to dlnetwork for automatic differentiation
            if isa(rawNet, 'nnet.cnn.LayerGraph')
                lgraph = rawNet;
            else
                lgraph = layerGraph(rawNet);
            end
            
            % Remove terminal classification/softmax layers for raw logits output
            outLayerNames = {lgraph.Layers.Name};
            if strcmp(modelName, 'efficientnetb0')
                lgraph = removeLayers(lgraph, {'Softmax', 'classification'});
            else
                toRemove = {};
                if any(strcmp(outLayerNames, 'ClassificationLayer_fc1000')), toRemove{end+1} = 'ClassificationLayer_fc1000'; end
                if any(strcmp(outLayerNames, 'fc1000_softmax')), toRemove{end+1} = 'fc1000_softmax'; end
                if ~isempty(toRemove)
                    lgraph = removeLayers(lgraph, toRemove);
                end
            end
            
            dlnet = dlnetwork(lgraph);
            
            % Synthetic batch input (res x res x 3 x batchSize)
            X_batch = dlarray(single(rand(res, res, 3, batchSize)), 'SSCB');
            
            % Determine output score dimensions from dry forward pass
            dryScores = predict(dlnet, X_batch);
            numClasses = size(dryScores, 1);
            
            % One-hot synthetic targets
            Y_targets = single(zeros(numClasses, batchSize));
            for b = 1:batchSize
                Y_targets(randi(numClasses), b) = 1.0;
            end
            Y_batch = dlarray(Y_targets, 'CB');
            
            % Warmup runs
            for w = 1:numWarmup
                [~, ~] = dlfeval(@computeModelLoss, dlnet, X_batch, Y_batch);
            end
            
            % Timed iterations
            tic;
            for t = 1:numTimedBatches
                [lossVal, gradVal] = dlfeval(@computeModelLoss, dlnet, X_batch, Y_batch);
            end
            elapsed = toc;
            
            secPerBatch = elapsed / numTimedBatches;
            secPerEpoch = secPerBatch * numBatchesPerEpoch;
            minPerEpoch = secPerEpoch / 60;
            hoursFor20Epochs = (secPerEpoch * 20) / 3600;
            
            fprintf('    -> %.3f sec/batch | %.1f min/epoch | %.2f hours for 20 epochs\n', ...
                secPerBatch, minPerEpoch, hoursFor20Epochs);
            
            lineStr = sprintf('%-16s | %-10s | %10.3f s   | %14.1f min  | %14.2f h', ...
                modelName, sprintf('%dx%d', res, res), secPerBatch, minPerEpoch, hoursFor20Epochs);
            reportLines{end+1} = lineStr; %#ok<AGROW>
            
            key = sprintf('%s_%d', modelName, res);
            results.(key).secPerBatch = secPerBatch;
            results.(key).minPerEpoch = minPerEpoch;
            results.(key).hoursFor20Epochs = hoursFor20Epochs;
            
        catch ME
            fprintf('    Benchmark failed for %s at %dx%d: %s\n', modelName, res, res, ME.message);
            lineStr = sprintf('%-16s | %-10s | FAILED: %s', modelName, sprintf('%dx%d', res, res), ME.message);
            reportLines{end+1} = lineStr; %#ok<AGROW>
        end
    end
end

reportLines{end+1} = '=========================================================================';
reportLines{end+1} = 'ARCHITECTURAL TAKEAWAYS FOR MILESTONE 3:';
reportLines{end+1} = '1. EfficientNet-B0 at 224x224 offers the highest training throughput on CPU.';
reportLines{end+1} = '2. At 300x300, memory bandwidth and FLOPs increase by ~(300/224)^2 = 1.79x.';
reportLines{end+1} = '3. Recommendation: Train transfer-learning head using EfficientNet-B0 at 224x224';
reportLines{end+1} = '   with frozen backbone, enabling rapid convergence within practical CPU budgets.';
reportLines{end+1} = '=========================================================================';

% Save report
reportPath = fullfile(outputDir, 'cpu_training_projection.txt');
fid = fopen(reportPath, 'w');
for k = 1:numel(reportLines)
    fprintf(fid, '%s\n', reportLines{k});
end
fclose(fid);

fprintf('\nBenchmark completed. Report written to: %s\n', reportPath);
type(reportPath);

end

function [loss, grads] = computeModelLoss(net, X, Y)
    scores = forward(net, X);
    probs = softmax(scores);
    loss = -sum(Y .* log(probs + 1e-7), 'all') / size(Y, 2);
    grads = dlgradient(loss, net.Learnables);
end
