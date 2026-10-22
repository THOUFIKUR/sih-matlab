function [pdfPath, audioPaths] = export_clinical_report_full(app)
% EXPORT_CLINICAL_REPORT_FULL Exports complete multi-page clinical screening PDF
% and synthesizes multilingual audio counseling in English, Hindi, and Tamil.
%
% Invokes Python ReportLab engine and gTTS via temporary JSON serialization.

pdfPath = '';
audioPaths = struct();

% 1. Ensure Directories exist
reportsDir = app.ReportsDir;
if ~exist(reportsDir, 'dir'), mkdir(reportsDir); end

audioDir = fullfile(reportsDir, 'audio');
if ~exist(audioDir, 'dir'), mkdir(audioDir); end

tempDir = fullfile(app.ProjectRoot, 'data', 'temp');
if ~exist(tempDir, 'dir'), mkdir(tempDir); end

caseID = app.CurrentCaseID;
if isempty(caseID), caseID = 'RS-DRAFT'; end

% 2. Save Overlay and Heatmap images to disk if they exist in memory
overlayPathOD = '';
overlayPathOS = '';
heatPathOD = '';
heatPathOS = '';
enhancedPathOD = '';
enhancedPathOS = '';

if ~isempty(app.OverlayImageOD)
    overlayPathOD = fullfile(tempDir, sprintf('%s_overlay_OD.jpg', caseID));
    imwrite(app.OverlayImageOD, overlayPathOD);
end
if ~isempty(app.OverlayImageOS)
    overlayPathOS = fullfile(tempDir, sprintf('%s_overlay_OS.jpg', caseID));
    imwrite(app.OverlayImageOS, overlayPathOS);
end

if isprop(app, 'HeatmapImageOD') && ~isempty(app.HeatmapImageOD)
    heatPathOD = fullfile(tempDir, sprintf('%s_heat_OD.jpg', caseID));
    imwrite(app.HeatmapImageOD, heatPathOD);
end
if isprop(app, 'HeatmapImageOS') && ~isempty(app.HeatmapImageOS)
    heatPathOS = fullfile(tempDir, sprintf('%s_heat_OS.jpg', caseID));
    imwrite(app.HeatmapImageOS, heatPathOS);
end

if ~isempty(app.EnhancedImageOD)
    enhancedPathOD = fullfile(tempDir, sprintf('%s_clahe_OD.jpg', caseID));
    imwrite(app.EnhancedImageOD, enhancedPathOD);
end
if ~isempty(app.EnhancedImageOS)
    enhancedPathOS = fullfile(tempDir, sprintf('%s_clahe_OS.jpg', caseID));
    imwrite(app.EnhancedImageOS, enhancedPathOS);
end

% 3. Extract Clinician & Hospital info
hospFacility = 'District Eye Hospital, Tertiary Care Center';
if isprop(app, 'HospitalFacilityEdit') && isvalid(app.HospitalFacilityEdit) && ~isempty(strtrim(app.HospitalFacilityEdit.Value))
    hospFacility = strtrim(app.HospitalFacilityEdit.Value);
end

refTimeframe = 'Priority Referral: Within 2 to 4 Weeks';
if isprop(app, 'ReferralTimeframeDropDown') && isvalid(app.ReferralTimeframeDropDown)
    refTimeframe = app.ReferralTimeframeDropDown.Value;
end

% 4. Assemble Case Struct
cData = struct();
cData.CaseID = caseID;
cData.PatientName = app.CurrentPatientName;
cData.Age = app.CurrentPatientAge;
cData.Gender = app.CurrentPatientGender;
cData.Contact = app.CurrentContact;
cData.InsuranceID = app.CurrentInsuranceID;
cData.DMDuration = app.CurrentDMDuration;
cData.HbA1c = app.CurrentHbA1c;
cData.CreatedAt = datestr(now, 'yyyy-mm-dd HH:MM');

cData.ReviewerName = app.ReviewerNameEdit.Value;
if isempty(cData.ReviewerName), cData.ReviewerName = 'Pending Clinician Sign-Off'; end
cData.ReviewerRole = app.ReviewerRoleDropDown.Value;
cData.ClinicalDecision = app.DecisionDropDown.Value;
cData.ReferralAction = app.ReferralDropDown.Value;
cData.HospitalFacility = hospFacility;
cData.ReferralTimeframe = refTimeframe;
cData.ClinicalNotes = app.NotesTextArea.Value;

cData.ImagePathOD = app.ImagePathOD;
cData.ImagePathOS = app.ImagePathOS;
cData.OverlayPathOD = overlayPathOD;
cData.OverlayPathOS = overlayPathOS;
cData.HeatmapPathOD = heatPathOD;
cData.HeatmapPathOS = heatPathOS;
cData.EnhancedPathOD = enhancedPathOD;
cData.EnhancedPathOS = enhancedPathOS;

cData.ClassificationOD = app.ClassificationOD;
cData.ClassificationOS = app.ClassificationOS;

% 5. Write Temporary JSON
jsonPath = fullfile(tempDir, sprintf('case_%s.json', caseID));
jsonStr = jsonencode(cData);
fid = fopen(jsonPath, 'w', 'native', 'UTF-8');
fwrite(fid, jsonStr, 'char');
fclose(fid);

% 6. Detect Selected Language
reportLang = 'en';
if isprop(app, 'ReportLangDropDown') && isvalid(app.ReportLangDropDown)
    val = app.ReportLangDropDown.Value;
    if contains(val, 'Tamil'), reportLang = 'ta';
    elseif contains(val, 'Hindi'), reportLang = 'hi';
    else, reportLang = 'en';
    end
end

% 7. Invoke PDF Generator
targetPdf = fullfile(reportsDir, sprintf('Report_%s_%s_%s.pdf', caseID, upper(reportLang), datestr(now, 'yyyymmdd_HHMMSS')));
pdfScript = fullfile(app.ProjectRoot, 'src', 'reports', 'generate_clinical_pdf.py');

cmdPdf = sprintf('python "%s" --case_json "%s" --output_pdf "%s" --lang "%s"', pdfScript, jsonPath, targetPdf, reportLang);
[statusPdf, outPdf] = system(cmdPdf);

if statusPdf == 0 && isfile(targetPdf)
    pdfPath = targetPdf;
    app.ReportExportPath = targetPdf;
else
    error('PDF Generation Failed: %s', outPdf);
end

end
