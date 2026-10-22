function cfg = dataset_config()
% DATASET_CONFIG Returns read-only path configuration for IDRiD, DRIVE, and samples.
%
% Strictly read-only access to reference datasets located in D:\sih2026\retino\data.
% Does not copy large images to the working project folder.

cfg = struct();

% Base data root
cfg.data_root = 'D:\sih2026\retino\data';
if ~exist(cfg.data_root, 'dir')
    % Fallback if moved
    altRoot = fullfile(fileparts(mfilename('fullpath')), '..', 'data');
    if exist(altRoot, 'dir')
        cfg.data_root = altRoot;
    end
end

%% 1. IDRiD Disease Grading (516 images)
gradingRoot = fullfile(cfg.data_root, 'idrid', 'B. Disease Grading');
cfg.idrid_grading.root = gradingRoot;
cfg.idrid_grading.train_images = fullfile(gradingRoot, '1. Original Images', 'a. Training Set');
cfg.idrid_grading.test_images  = fullfile(gradingRoot, '1. Original Images', 'b. Testing Set');
cfg.idrid_grading.train_labels = fullfile(gradingRoot, '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv');
cfg.idrid_grading.test_labels  = fullfile(gradingRoot, '2. Groundtruths', 'b. IDRiD_Disease Grading_Testing Labels.csv');

%% 2. IDRiD Localization (516 images: OD and Fovea Centers)
locRoot = fullfile(cfg.data_root, 'idrid', 'C. Localization');
cfg.idrid_localization.root = locRoot;
cfg.idrid_localization.train_images = fullfile(locRoot, '1. Original Images', 'a. Training Set');
cfg.idrid_localization.test_images  = fullfile(locRoot, '1. Original Images', 'b. Testing Set');
cfg.idrid_localization.od_train_csv = fullfile(locRoot, '2. Groundtruths', '1. Optic Disc Center Location', 'a. IDRiD_OD_Center_Training Set_Markups.csv');
cfg.idrid_localization.od_test_csv  = fullfile(locRoot, '2. Groundtruths', '1. Optic Disc Center Location', 'b. IDRiD_OD_Center_Testing Set_Markups.csv');
cfg.idrid_localization.fovea_train_csv = fullfile(locRoot, '2. Groundtruths', '2. Fovea Center Location', 'IDRiD_Fovea_Center_Training Set_Markups.csv');
cfg.idrid_localization.fovea_test_csv  = fullfile(locRoot, '2. Groundtruths', '2. Fovea Center Location', 'IDRiD_Fovea_Center_Testing Set_Markups.csv');

%% 3. IDRiD Segmentation (81 images: MA, Haemorrhages, Hard Exudates, Soft Exudates, Optic Disc)
segRoot = fullfile(cfg.data_root, 'idrid', 'A. Segmentation');
cfg.idrid_segmentation.root = segRoot;
cfg.idrid_segmentation.train_images = fullfile(segRoot, '1. Original Images', 'a. Training Set');
cfg.idrid_segmentation.test_images  = fullfile(segRoot, '1. Original Images', 'b. Testing Set');
cfg.idrid_segmentation.train_masks  = fullfile(segRoot, '2. All Segmentation Groundtruths', 'a. Training Set');
cfg.idrid_segmentation.test_masks   = fullfile(segRoot, '2. All Segmentation Groundtruths', 'b. Testing Set');

%% 4. DRIVE Dataset (Vessel Extraction Benchmark)
driveRoot = fullfile(cfg.data_root, 'drive');
cfg.drive.root = driveRoot;
cfg.drive.train_images = fullfile(driveRoot, 'training', 'images');
cfg.drive.train_masks  = fullfile(driveRoot, 'training', 'mask');
cfg.drive.train_manual = fullfile(driveRoot, 'training', '1st_manual');
cfg.drive.test_images  = fullfile(driveRoot, 'test', 'images');
cfg.drive.test_masks   = fullfile(driveRoot, 'test', 'mask');

%% 5. Sample Images
cfg.samples_dir = fullfile(cfg.data_root, 'samples', 'idrid_samples');

end
