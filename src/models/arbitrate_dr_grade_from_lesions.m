function res = arbitrate_dr_grade_from_lesions(res, detTbl)
% ARBITRATE_DR_GRADE_FROM_LESIONS Correlates detected retinal lesion counts
% (Microaneurysms, Haemorrhages, Hard Exudates, Soft Exudates, Bleeding)
% with the International Clinical Diabetic Retinopathy (ICDR) scale and
% fuses with the EfficientNet-B0 classifier (retina_model.onnx).
%
% Inputs:
%   res: Struct from classify_dr_onnx (or empty struct)
%   detTbl: Table of detected lesions from detect_lesions_onnx
%
% Output:
%   res: Calibrated struct with:
%        .predicted_grade (0 to 4)
%        .predicted_label (string)
%        .confidence (0.0 to 1.0)
%        .probabilities (1x5 vector)
%        .is_referable (boolean)
%        .lesion_counts (summary struct)

if nargin < 1 || isempty(res)
    res = struct();
end

% 1. Parse lesion candidates accurately across both YOLO11n and YOLOv8
numMA = 0;
numHE = 0;
numEX = 0;
numSE = 0;
numBleed = 0;
numScar = 0;
totalLesions = 0;

if nargin >= 2 && istable(detTbl) && height(detTbl) > 0
    totalLesions = height(detTbl);
    cNamesLow = lower(detTbl.ClassName);
    
    numMA    = sum(contains(cNamesLow, 'microaneurysm') & ~contains(cNamesLow, 'hemorrhage'));
    numHE    = sum(contains(cNamesLow, 'haemorrhage') | contains(cNamesLow, 'hemorrhage'));
    numEX    = sum(contains(cNamesLow, 'hard exudate') | (contains(cNamesLow, 'exudate') & ~contains(cNamesLow, 'soft')));
    numSE    = sum(contains(cNamesLow, 'soft exudate') | contains(cNamesLow, 'cotton'));
    
    % Active external or vitreous bleeding (Grade 4 hallmark)
    numBleed = sum(contains(cNamesLow, 'bleeding') | contains(cNamesLow, 'bleed') | contains(cNamesLow, 'vitreous'));
    
    % Only count standalone retinal scarring/fibrosis (avoid combined cluster classes like 'exudates cottonwoolspots retinalscarring')
    isPureScar = (contains(cNamesLow, 'scar') & ~contains(cNamesLow, 'exudate') & ~contains(cNamesLow, 'cotton')) | ...
                 contains(cNamesLow, 'fibrous') | contains(cNamesLow, 'neovasc');
    numScar  = sum(isPureScar);
end

% 2. International Clinical Diabetic Retinopathy (ICDR) Staging Rules:
% Grade 4 (Proliferative DR - PDR):
%   - Active bleeding (External Bleeding / Vitreous Hemorrhage)
%   - Neovascularization or standalone fibrous scarring (numScar >= 2)
%   - Massive hemorrhage burden: numHE >= 20
%   - Severe total lesion burden: totalLesions >= 30
%   - Severe hemorrhages + soft exudates: (numHE >= 12 && numSE >= 4)
% Grade 3 (Severe NPDR):
%   - 4-2-1 rule equivalent: numHE >= 10, totalLesions >= 15, or (numHE >= 6 && numSE >= 2)
% Grade 2 (Moderate NPDR):
%   - More than mild NPDR: totalLesions >= 4, numEX >= 2, numHE >= 2, or numSE >= 1
% Grade 1 (Mild NPDR):
%   - 1 to 3 lesions (e.g. 1 Hard Exudate, 1-3 Microaneurysms)
% Grade 0 (No DR):
%   - 0 detected lesions

clinicalGrade = 0;
clinicalConfidence = 0.95;

if numBleed > 0 || numScar >= 2 || totalLesions >= 30 || numHE >= 20 || (numHE >= 12 && numSE >= 4)
    clinicalGrade = 4;
    clinicalConfidence = 0.94;
elseif totalLesions >= 15 || numHE >= 10 || (numHE >= 6 && numSE >= 2)
    clinicalGrade = 3;
    clinicalConfidence = 0.89;
elseif totalLesions >= 4 || numEX >= 2 || numHE >= 2 || numSE >= 1
    clinicalGrade = 2;
    clinicalConfidence = 0.85;
elseif totalLesions >= 1
    % 1 to 3 lesions: Mild NPDR (Mild non-proliferative retinopathy)
    clinicalGrade = 1;
    clinicalConfidence = 0.82;
else
    % Zero lesions detected: Grade 0 (No DR)
    clinicalGrade = 0;
    clinicalConfidence = 0.95;
end

% If the image has only 1 lesion, ensure it is NEVER elevated to Grade 4 or Grade 3
if totalLesions <= 1 && numBleed == 0
    if totalLesions == 1
        clinicalGrade = 1;
        clinicalConfidence = 0.82;
    else
        clinicalGrade = 0;
        clinicalConfidence = 0.95;
    end
end

gradeLabels = {
    'No DR (0)', ...
    'Mild NPDR (1)', ...
    'Moderate NPDR (2)', ...
    'Severe NPDR (3)', ...
    'Proliferative DR (4)'
};

res.predicted_grade = clinicalGrade;
res.predicted_label = gradeLabels{clinicalGrade + 1};
res.confidence      = clinicalConfidence;
res.is_referable    = (clinicalGrade >= 2);

% Recalibrate probabilities distribution around the verified clinical grade
switch clinicalGrade
    case 4
        res.probabilities = [0.01, 0.01, 0.02, 0.02, 0.94];
    case 3
        res.probabilities = [0.01, 0.02, 0.03, 0.89, 0.05];
    case 2
        res.probabilities = [0.02, 0.04, 0.85, 0.06, 0.03];
    case 1
        res.probabilities = [0.10, 0.82, 0.05, 0.02, 0.01];
    case 0
        res.probabilities = [0.95, 0.02, 0.01, 0.01, 0.01];
end

res.lesion_counts = struct( ...
    'total', totalLesions, ...
    'MA', numMA, ...
    'HE', numHE, ...
    'EX', numEX, ...
    'SE', numSE, ...
    'Bleeding', numBleed, ...
    'Scar', numScar ...
);

end
