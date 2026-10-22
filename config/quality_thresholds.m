function thresh = quality_thresholds()
% QUALITY_THRESHOLDS Returns quality assessment thresholds marked EXPERIMENTAL.
%
% These thresholds categorize retinal fundus scans into Good, Borderline, or Ungradable.
% Calibrated empirically against IDRiD and DRIVE benchmarks.
%
% Status: EXPERIMENTAL (Subject to clinical validation)

thresh = struct();

% 1. Focus (2D Laplacian Variance on Luminance)
thresh.focus.ungradable_below  = 8.0;   % Below 8.0 indicates severe defocus / motion blur
thresh.focus.borderline_below = 18.0;  % 8.0 - 18.0 indicates moderate blur (needs enhancement)
thresh.focus.good_min         = 18.0;  % >= 18.0 indicates crisp vascular edges

% 2. Illumination & Exposure (Mean Intensity [0, 255])
thresh.illumination.underexposed_below = 25.0;  % Image too dark (insufficient flash/dilation)
thresh.illumination.overexposed_above  = 215.0; % Image washed out by specular flash
thresh.illumination.entropy_min        = 3.5;   % Shannon entropy minimum (information content)

% 3. Field of View (FOV Retinal Tissue Percentage [0, 100])
thresh.fov.ungradable_below  = 38.0; % Severe pupil clipping or lid obstruction
thresh.fov.borderline_below = 50.0; % Borderline pupil alignment
thresh.fov.good_min         = 50.0; % Optimal central/nasal retinal aperture

% 4. Optic Disc Visibility (Candidate region brightness contrast)
thresh.optic_disc.contrast_min = 1.15; % Optic disc region must exceed local background

% 5. Vessel Visibility (High-frequency vessel gradient contrast)
thresh.vessels.gradient_min = 1.5;   % Minimum vascular edge energy in green channel

% Metadata
thresh.calibration_status = 'EXPERIMENTAL';
thresh.version = '1.0';

end
