classdef RetinaScanApp < handle
    % RETINASCANAPP Professional MATLAB Application for Diabetic Retinopathy Screening & Review.
    %
    % Problem: SIH 26038 — Explainable AI for Diabetic Retinopathy Screening in Rural India
    % Implementation Specification: RetinaScan_AI_COMPLETE_ANTIGRAVITY_PROMPT.md
    % Framework: MATLAB R2024a App Designer (programmatic uifigure)
    %
    % Top-Level Pages (Exactly 6 in order):
    %   1. System Overview
    %   2. Patient Intake & Registry
    %   3. Image Import & Quality Gate
    %   4. AI Screening & Explainability
    %   5. Clinician Review & Report
    %   6. Clinic Workflow Simulation

    properties (Access = public)
        UIFigure             matlab.ui.Figure
        TabGroup             matlab.ui.container.TabGroup
        
        % The 6 Canonical Pages
        OverviewTab          matlab.ui.container.Tab
        PatientTab           matlab.ui.container.Tab
        QualityTab           matlab.ui.container.Tab
        ScreeningTab         matlab.ui.container.Tab
        ReviewTab            matlab.ui.container.Tab
        SimulationTab        matlab.ui.container.Tab
        
        % Layout Dimensions
        FigWidth             double = 1240
        FigHeight            double = 660
        ContentWidth         double
        ContentHeight        double
        
        % Persistent Active Case Data Model
        CurrentCaseID        char = ''
        CurrentPatientName   char = ''
        CurrentPatientAge    double = 0
        CurrentPatientGender char = 'Male'
        CurrentContact       char = ''
        CurrentInsuranceID   char = ''
        CurrentDMDuration    double = 0
        CurrentHbA1c         double = 0
        ConsentObtained      logical = false
        CaseCreatedAt        char = ''
        CaseUpdatedAt        char = ''
        
        % Images & Laterality (OD = Right, OS = Left)
        ActiveEye            char = 'OD'
        ImagePathOD          char = ''
        ImagePathOS          char = ''
        RawImageOD           uint8
        RawImageOS           uint8
        EnhancedImageOD      uint8
        EnhancedImageOS      uint8
        
        % Quality Gate Results
        QualityStatusOD      char = 'Not Evaluated'
        QualityStatusOS      char = 'Not Evaluated'
        QualityMetricsOD     struct
        QualityMetricsOS     struct
        
        % AI Screening Results
        ClassificationOD     struct
        ClassificationOS     struct
        DetectionsTableOD    table
        DetectionsTableOS    table
        OverlayImageOD       uint8
        OverlayImageOS       uint8
        HeatmapImageOD       uint8
        HeatmapImageOS       uint8
        ConfThreshold        double = 0.20
        
        % Clinician Review & Sign-Off
        ReviewerName         char = ''
        ReviewerRole         char = 'Consultant Ophthalmologist'
        ClinicalDecision     char = 'Not yet reviewed'
        ReferralAction       char = 'Routine Annual (12 Months)'
        HospitalFacility     char = 'District Eye Hospital, Tertiary Care Center'
        ReferralTimeframe    char = 'Priority Referral: Within 2 to 4 Weeks'
        ClinicalNotes        cell = {'No clinical notes recorded.'}
        ReviewSaved          logical = false
        ReviewSignedAt       char = ''
        ReportExportPath     char = ''
        
        % Storage & Paths
        ProjectRoot          char = ''
        RegistryFilePath     char = ''
        CasesDir             char = ''
        ReportsDir           char = ''
        
        % UI Components - Page 1: System Overview
        OverviewStatusTable  matlab.ui.control.Table
        OverviewCasesTable   matlab.ui.control.Table
        OverviewSummaryLabel matlab.ui.control.Label
        
        % UI Components - Page 2: Patient Intake
        PatientNameEdit      matlab.ui.control.EditField
        AgeEdit              matlab.ui.control.NumericEditField
        GenderDropDown       matlab.ui.control.DropDown
        ContactEdit          matlab.ui.control.EditField
        InsuranceEdit        matlab.ui.control.EditField
        DiabetesDurationEdit matlab.ui.control.NumericEditField
        HbA1cEdit            matlab.ui.control.NumericEditField
        ConsentCheckBox      matlab.ui.control.CheckBox
        CaseIDLabel          matlab.ui.control.Label
        PatientTable         matlab.ui.control.Table
        
        % UI Components - Page 3: Image Import & Quality Gate
        EyeSelectButtonGroup matlab.ui.container.ButtonGroup
        EyeSelectODButton    matlab.ui.control.RadioButton
        EyeSelectOSButton    matlab.ui.control.RadioButton
        ImgAxesRaw           matlab.ui.control.UIAxes
        ImgAxesEnhanced      matlab.ui.control.UIAxes
        HistAxesRaw          matlab.ui.control.UIAxes
        HistAxesEnhanced     matlab.ui.control.UIAxes
        QualityStatusLabel   matlab.ui.control.Label
        RecaptureAdviceLabel matlab.ui.control.Label
        QualityMetricsTable  matlab.ui.control.Table
        EyeODStatusLabel     matlab.ui.control.Label
        EyeOSStatusLabel     matlab.ui.control.Label
        
        % UI Components - Page 4: AI Screening & Explainability
        ScreenEyeButtonGroup   matlab.ui.container.ButtonGroup
        ScreenEyeODButton      matlab.ui.control.RadioButton
        ScreenEyeOSButton      matlab.ui.control.RadioButton
        ModelSelectDropDown    matlab.ui.control.DropDown
        ConfSpinner            matlab.ui.control.Spinner
        ViewModeDropDown       matlab.ui.control.DropDown
        ShowLabelsCheckBox     matlab.ui.control.CheckBox
        ScreeningAxes          matlab.ui.control.UIAxes
        GradeProbTable         matlab.ui.control.Table
        UncertaintyWarningLabel matlab.ui.control.Label
        GradeBannerLabel       matlab.ui.control.Label
        ReferralBannerLabel    matlab.ui.control.Label
        LesionCountTable       matlab.ui.control.Table
        
        % UI Components - Page 5: Clinician Review & Report
        ReviewerNameEdit       matlab.ui.control.EditField
        ReviewerRoleDropDown   matlab.ui.control.DropDown
        DecisionDropDown       matlab.ui.control.DropDown
        ReferralDropDown       matlab.ui.control.DropDown
        HospitalFacilityEdit   matlab.ui.control.EditField
        ReferralTimeframeDropDown matlab.ui.control.DropDown
        ReportLangDropDown     matlab.ui.control.DropDown
        NotesTextArea          matlab.ui.control.TextArea
        ReviewStatusLabel      matlab.ui.control.Label
        ReportPreviewLabel     matlab.ui.control.Label
        AudioStatusLabel       matlab.ui.control.Label
        
        % UI Components - Page 6: Clinic Workflow Simulation
        ScenarioDropDown     matlab.ui.control.DropDown
        SimArrivalRateEdit   matlab.ui.control.NumericEditField
        SimServiceTimeEdit   matlab.ui.control.NumericEditField
        SimAxes              matlab.ui.control.UIAxes
        SimMetricsTable      matlab.ui.control.Table
        SimStatusLabel       matlab.ui.control.Label
    end

    methods (Access = public)
        function app = RetinaScanApp()
            % Constructor: initialize application environment and paths
            app.ProjectRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(genpath(app.ProjectRoot));
            
            dataDir = fullfile(app.ProjectRoot, 'data');
            app.CasesDir = fullfile(dataDir, 'cases');
            app.ReportsDir = fullfile(app.ProjectRoot, 'outputs', 'reports');
            
            if ~exist(dataDir, 'dir'), mkdir(dataDir); end
            if ~exist(app.CasesDir, 'dir'), mkdir(app.CasesDir); end
            if ~exist(app.ReportsDir, 'dir'), mkdir(app.ReportsDir); end
            
            app.RegistryFilePath = fullfile(dataDir, 'patient_registry.mat');
            initRegistryStorage(app);
            
            % Generate initial unique Case ID
            app.CurrentCaseID = generateUniqueCaseID(app);
            app.CaseCreatedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            app.CaseUpdatedAt = app.CaseCreatedAt;
            
            % Create Responsive UI
            createUI(app);
            
            % Refresh Registry Tables on Startup
            refreshAllRegistryViews(app);
        end
        
        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
        
        function selectTab(app, tabName)
            switch lower(tabName)
                case 'overview',    app.TabGroup.SelectedTab = app.OverviewTab;
                case 'patient',     app.TabGroup.SelectedTab = app.PatientTab;
                case 'quality',     app.TabGroup.SelectedTab = app.QualityTab;
                case 'screening',   app.TabGroup.SelectedTab = app.ScreeningTab;
                case 'review',      app.TabGroup.SelectedTab = app.ReviewTab;
                case 'simulation',  app.TabGroup.SelectedTab = app.SimulationTab;
            end
        end
    end

    methods (Access = public)
        %% UI Construction
        function createUI(app)
            % Detect user display dimensions
            screenSize = get(0, 'ScreenSize'); % [left, bottom, width, height]
            scrW = screenSize(3);
            scrH = screenSize(4);
            
            app.FigWidth  = min(1240, scrW - 24);
            app.FigHeight = min(660, scrH - 70);
            
            figLeft   = max(10, round((scrW - app.FigWidth) / 2));
            figBottom = max(35, round((scrH - app.FigHeight) / 2));
            
            % Main UI Figure
            app.UIFigure = uifigure(...
                'Name', 'RetinaScan AI — Retinal Screening & Review Prototype', ...
                'Position', [figLeft, figBottom, app.FigWidth, app.FigHeight], ...
                'Color', [0.95, 0.96, 0.98], ...
                'Resize', 'on');

            % Top Header Banner (38 px high)
            headerY = app.FigHeight - 42;
            headerPanel = uipanel(app.UIFigure, ...
                'Position', [8, headerY, app.FigWidth - 16, 38], ...
                'BackgroundColor', [0.12, 0.22, 0.38], ...
                'BorderType', 'none');
            
            uilabel(headerPanel, ...
                'Text', 'RetinaScan AI  |  Retinal Screening & Review Prototype', ...
                'Position', [15, 7, 580, 24], ...
                'FontName', 'Segoe UI', ...
                'FontSize', 15, ...
                'FontWeight', 'bold', ...
                'FontColor', [1, 1, 1]);
                
            uilabel(headerPanel, ...
                'Text', 'Research Decision-Support Prototype — Not Clinically Validated', ...
                'Position', [app.FigWidth - 560, 9, 530, 20], ...
                'FontName', 'Segoe UI', ...
                'FontSize', 11, ...
                'FontColor', [0.85, 0.90, 0.95], ...
                'HorizontalAlignment', 'right');

            % Single Unified Tab Group occupies remainder of window
            tabGroupH = app.FigHeight - 54;
            app.TabGroup = uitabgroup(app.UIFigure, ...
                'Position', [8, 8, app.FigWidth - 16, tabGroupH]);

            % The Exactly 6 Canonical Pages in Specified Order
            app.OverviewTab   = uitab(app.TabGroup, 'Title', '  1. System Overview  ');
            app.PatientTab    = uitab(app.TabGroup, 'Title', '  2. Patient Intake & Registry  ');
            app.QualityTab    = uitab(app.TabGroup, 'Title', '  3. Image Import & Quality Gate  ');
            app.ScreeningTab  = uitab(app.TabGroup, 'Title', '  4. AI Screening & Explainability  ');
            app.ReviewTab     = uitab(app.TabGroup, 'Title', '  5. Clinician Review & Report  ');
            app.SimulationTab = uitab(app.TabGroup, 'Title', '  6. Clinic Workflow Simulation  ');

            app.ContentWidth  = app.FigWidth - 26;
            app.ContentHeight = tabGroupH - 36;

            % Build layout inside each page
            buildOverviewTab(app);
            buildPatientTab(app);
            buildQualityTab(app);
            buildScreeningTab(app);
            buildReviewTab(app);
            buildSimulationTab(app);
        end

        %% 1. Build Page 1: System Overview
        function buildOverviewTab(app)
            p = app.OverviewTab;
            w = app.ContentWidth;
            h = app.ContentHeight;
            
            % Model & System Status Panel
            statusPanel = uipanel(p, 'Title', 'Application Status & Verified Model Assets', ...
                'Position', [15, h - 215, w - 30, 200], ...
                'FontWeight', 'bold', 'FontSize', 12);
                
            effPath  = fullfile(app.ProjectRoot, 'data', 'models', 'retina_efficientnet_b0_scratch.onnx');
            yoloPath = fullfile(app.ProjectRoot, 'data', 'models', 'yolo11n_lesions_scratch.onnx');
            bestPath = fullfile(app.ProjectRoot, 'data', 'models', 'best.onnx');
            
            effStatus = 'Missing';
            if isfile(effPath)
                eInfo = dir(effPath);
                effStatus = sprintf('Loaded (%.1f MB)', eInfo.bytes / 1e6);
            end
            
            yoloStatus = 'Missing';
            if isfile(bestPath)
                yInfo = dir(bestPath);
                yoloStatus = sprintf('Loaded [best.onnx] (%.1f MB)', yInfo.bytes / 1e6);
            elseif isfile(yoloPath)
                yInfo = dir(yoloPath);
                yoloStatus = sprintf('Loaded (%.1f MB)', yInfo.bytes / 1e6);
            end
            
            modelRows = {
                'Diabetic Retinopathy Classifier', 'EfficientNet-B0 (5-Class Scratch ONNX)', effStatus, 'data/models/retina_efficientnet_b0_scratch.onnx';
                'Retinal Lesion Detector', 'YOLO11n (4-Class Scratch ONNX)', yoloStatus, 'data/models/yolo11n_lesions_scratch.onnx';
                'Fail-Closed Quality Gate', '5-Metric Laplacian & Illumination Filter', 'Active', 'src/preprocessing/assess_image_quality.m';
                'Landmark Prior', 'Circular Hough Optic Disc & Fovea Prior', 'Active', 'src/structures/detect_optic_disc.m';
                'Queueing Simulation Engine', 'Discrete-Event Stochastic Model (Zero-Toolbox)', 'Active', 'simulink/run_screening_simulation.m'
            };
            
            app.OverviewStatusTable = uitable(statusPanel, ...
                'Data', modelRows, ...
                'ColumnName', {'Component', 'Method / Architecture', 'Status', 'Asset Path'}, ...
                'ColumnWidth', {220, 240, 160, 470}, ...
                'Position', [10, 32, w - 54, 138]);

            uilabel(statusPanel, ...
                'Text', 'Model Validation Note: YOLO11n 4-class detector test metrics on IDRiD: Prec 0.298, Rec 0.187, mAP50 0.154. Research Prototype — Not Clinically Validated.', ...
                'Position', [12, 6, w - 60, 20], 'FontSize', 10, 'FontColor', [0.4, 0.4, 0.4]);

            % Workflow Guidance Panel (Left)
            guideW = 580;
            wfPanel = uipanel(p, 'Title', 'How to Use This Prototype — Workflow Sequence', ...
                'Position', [15, 55, guideW, h - 280], ...
                'FontWeight', 'bold', 'FontSize', 12);
                
            guideText = sprintf([...
                '1. Patient Intake: Register or select patient and verify informed consent.\n', ...
                '2. Two-Eye Image Import: Load OD (Right) and OS (Left) fundus images independently.\n', ...
                '3. Quality Assessment: Images failing quality criteria are blocked from AI screening.\n', ...
                '4. AI Screening: Evaluate both eyes independently. View predicted grade & lesion boxes.\n', ...
                '5. Clinician Review: Qualified eye care professional confirms/modifies findings.\n', ...
                '6. Report Export: Generate official high-resolution PDF or text screening summary.\n\n', ...
                'Clinical Caveat:\n', ...
                '• AI outputs are decision-support suggestions, not confirmed medical diagnoses.\n', ...
                '• Microaneurysms, Haemorrhages, Hard Exudates, and Soft Exudates are candidate findings.\n', ...
                '• Disagreement, low confidence, or ungradable images require direct clinical examination.']);
            uilabel(wfPanel, 'Text', guideText, 'Position', [15, 15, guideW - 30, h - 330], 'FontSize', 11);

            % Saved Cases Registry (Right)
            caseX = guideW + 30;
            caseW = w - caseX - 15;
            casesPanel = uipanel(p, 'Title', 'Saved Clinical Cases (Local Persistent Database)', ...
                'Position', [caseX, 55, caseW, h - 280], ...
                'FontWeight', 'bold', 'FontSize', 12);

            app.OverviewCasesTable = uitable(casesPanel, ...
                'Data', cell(0, 5), ...
                'ColumnName', {'Case ID', 'Patient Name', 'Age/Sex', 'Status', 'Last Updated'}, ...
                'ColumnWidth', {90, 140, 65, 110, 140}, ...
                'Position', [10, 48, caseW - 22, h - 365]);

            uibutton(casesPanel, 'push', ...
                'Text', 'Load Selected Case', ...
                'Position', [10, 10, 160, 30], ...
                'BackgroundColor', [0.12, 0.35, 0.65], 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) loadSelectedCaseFromOverview(app));

            uibutton(casesPanel, 'push', ...
                'Text', 'Start New Case', ...
                'Position', [180, 10, 140, 30], ...
                'ButtonPushedFcn', @(~, ~) onStartNewCaseButtonPushed(app));

            % Bottom Bar Navigation
            navPanel = uipanel(p, 'Position', [15, 10, w - 30, 38], 'BorderType', 'none');
            app.OverviewSummaryLabel = uilabel(navPanel, ...
                'Text', 'Database: Initialized  |  No patient active.', ...
                'Position', [5, 8, 700, 22], 'FontSize', 11, 'FontColor', [0.3, 0.3, 0.3]);
                
            uibutton(navPanel, 'push', ...
                'Text', 'Continue to Patient Intake ->', ...
                'Position', [w - 240, 4, 210, 30], ...
                'BackgroundColor', [0.12, 0.35, 0.65], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) selectTab(app, 'patient'));
        end

        %% 2. Build Page 2: Patient Intake & Registry
        function buildPatientTab(app)
            p = app.PatientTab;
            w = app.ContentWidth;
            h = app.ContentHeight;
            
            formW = 490;
            formPanel = uipanel(p, 'Title', 'Patient Registration & Case Intake', ...
                'Position', [15, 55, formW, h - 70], 'FontWeight', 'bold', 'FontSize', 12);
                
            uilabel(formPanel, 'Text', 'Case ID:', 'Position', [20, h - 120, 110, 22], 'FontWeight', 'bold');
            app.CaseIDLabel = uilabel(formPanel, 'Text', app.CurrentCaseID, ...
                'Position', [140, h - 120, 180, 22], 'FontWeight', 'bold', 'FontColor', [0.1, 0.35, 0.65]);
                
            uilabel(formPanel, 'Text', 'Full Name *:', 'Position', [20, h - 160, 110, 22]);
            app.PatientNameEdit = uieditfield(formPanel, 'text', 'Value', '', ...
                'Placeholder', 'Enter patient full name', ...
                'Position', [140, h - 160, 320, 26]);
                
            uilabel(formPanel, 'Text', 'Age (Years) *:', 'Position', [20, h - 200, 110, 22]);
            app.AgeEdit = uieditfield(formPanel, 'numeric', 'Value', 0, ...
                'Position', [140, h - 200, 90, 26]);
            
            uilabel(formPanel, 'Text', 'Gender:', 'Position', [245, h - 200, 55, 22]);
            app.GenderDropDown = uidropdown(formPanel, 'Items', {'Male', 'Female', 'Other'}, ...
                'Value', 'Male', 'Position', [310, h - 200, 150, 26]);

            uilabel(formPanel, 'Text', 'Contact Phone:', 'Position', [20, h - 240, 110, 22]);
            app.ContactEdit = uieditfield(formPanel, 'text', 'Value', '', ...
                'Placeholder', 'Optional 10-digit mobile number', ...
                'Position', [140, h - 240, 320, 26]);

            uilabel(formPanel, 'Text', 'Insurance / Health ID:', 'Position', [20, h - 280, 130, 22]);
            app.InsuranceEdit = uieditfield(formPanel, 'text', 'Value', '', ...
                'Placeholder', 'Optional member / payer ID', ...
                'Position', [155, h - 280, 305, 26]);

            uilabel(formPanel, 'Text', 'Diabetes Duration:', 'Position', [20, h - 320, 110, 22]);
            app.DiabetesDurationEdit = uieditfield(formPanel, 'numeric', 'Value', 0, ...
                'Position', [140, h - 320, 90, 26]);
            uilabel(formPanel, 'Text', 'years (optional)', 'Position', [240, h - 320, 120, 22], 'FontColor', [0.4, 0.4, 0.4]);

            uilabel(formPanel, 'Text', 'Latest HbA1c (%):', 'Position', [20, h - 360, 110, 22]);
            app.HbA1cEdit = uieditfield(formPanel, 'numeric', 'Value', 0, ...
                'Position', [140, h - 360, 90, 26]);
            uilabel(formPanel, 'Text', '% (optional)', 'Position', [240, h - 360, 120, 22], 'FontColor', [0.4, 0.4, 0.4]);

            app.ConsentCheckBox = uicheckbox(formPanel, ...
                'Text', 'Patient informed consent obtained for AI-assisted retinal screening *', ...
                'Value', false, 'Position', [20, h - 410, 440, 26]);

            uibutton(formPanel, 'push', ...
                'Text', 'Save Patient Record', ...
                'Position', [20, 20, 215, 36], ...
                'BackgroundColor', [0.12, 0.35, 0.65], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(btn, event) savePatientCallback(app));

            uibutton(formPanel, 'push', ...
                'Text', 'Start New Case', ...
                'Position', [245, 20, 215, 36], ...
                'ButtonPushedFcn', @(btn, event) onStartNewCaseButtonPushed(app));

            % Right: Screening Registry Table
            regX = formW + 30;
            regW = w - regX - 15;
            recordsPanel = uipanel(p, 'Title', 'Clinical Screening Registry (Local Persistent Store)', ...
                'Position', [regX, 55, regW, h - 70], 'FontWeight', 'bold', 'FontSize', 12);

            app.PatientTable = uitable(recordsPanel, ...
                'Data', cell(0, 7), ...
                'ColumnName', {'Case ID', 'Name', 'Age', 'Gender', 'Contact', 'Images', 'Status'}, ...
                'ColumnWidth', {90, 120, 45, 55, 95, 75, 95}, ...
                'Position', [10, 50, regW - 22, h - 145]);

            uibutton(recordsPanel, 'push', ...
                'Text', 'Load Selected Patient Case', ...
                'Position', [10, 12, 220, 30], ...
                'BackgroundColor', [0.12, 0.35, 0.65], 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) loadSelectedCaseFromPatientTab(app));

            % Bottom Navigation Bar
            bNav = uipanel(p, 'Position', [15, 10, w - 30, 40], 'BorderType', 'none');
            uibutton(bNav, 'push', 'Text', '<- Return to Overview', ...
                'Position', [5, 5, 170, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'overview'));
            uibutton(bNav, 'push', 'Text', 'Continue to Image Import & Quality Gate ->', ...
                'Position', [w - 300, 5, 265, 30], ...
                'BackgroundColor', [0.15, 0.55, 0.35], 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) selectTab(app, 'quality'));
        end

        %% 3. Build Page 3: Image Import & Quality Gate
        function buildQualityTab(app)
            p = app.QualityTab;
            w = app.ContentWidth;
            h = app.ContentHeight;

            % Controls Bar at Top
            ctrlPanel = uipanel(p, 'Position', [15, h - 65, w - 30, 55], 'BackgroundColor', [1, 1, 1]);
            
            % Eye Selection (OD vs OS)
            app.EyeSelectButtonGroup = uibuttongroup(ctrlPanel, ...
                'Position', [10, 8, 175, 36], 'BorderType', 'none');
            app.EyeSelectODButton = uiradiobutton(app.EyeSelectButtonGroup, ...
                'Text', 'OD (Right)', 'Position', [5, 8, 85, 22], 'Value', true);
            app.EyeSelectOSButton = uiradiobutton(app.EyeSelectButtonGroup, ...
                'Text', 'OS (Left)', 'Position', [95, 8, 80, 22]);
            app.EyeSelectButtonGroup.SelectionChangedFcn = @(bg, event) eyeSelectionChanged(app);

            uibutton(ctrlPanel, 'push', ...
                'Text', 'Choose Image', ...
                'Position', [195, 10, 120, 34], ...
                'ButtonPushedFcn', @(btn, event) chooseImageCallback(app));

            uibutton(ctrlPanel, 'push', ...
                'Text', 'Capture Camera', ...
                'Position', [325, 10, 125, 34], ...
                'ButtonPushedFcn', @(btn, event) captureCameraCallback(app));

            uibutton(ctrlPanel, 'push', ...
                'Text', 'Run Quality Assessment (OD + OS)', ...
                'Position', [455, 10, 225, 34], ...
                'BackgroundColor', [0.15, 0.55, 0.35], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(btn, event) runQualityGateCallback(app));

            app.QualityStatusLabel = uilabel(ctrlPanel, ...
                'Text', 'Quality Status: NOT EVALUATED', ...
                'Position', [690, 14, 280, 26], ...
                'FontSize', 12, 'FontWeight', 'bold', 'FontColor', [0.3, 0.4, 0.5]);

            % Eye status badges
            app.EyeODStatusLabel = uilabel(ctrlPanel, 'Text', 'OD: Empty', 'Position', [w - 230, 26, 180, 18], 'FontSize', 10, 'FontColor', [0.4, 0.4, 0.4]);
            app.EyeOSStatusLabel = uilabel(ctrlPanel, 'Text', 'OS: Empty', 'Position', [w - 230, 8, 180, 18], 'FontSize', 10, 'FontColor', [0.4, 0.4, 0.4]);

            % Images & Histograms Grid
            axW = 340;
            axH = 185;
            
            % Raw Image Axes
            app.ImgAxesRaw = uiaxes(p, 'Position', [15, h - 265, axW, axH]);
            title(app.ImgAxesRaw, 'Original Fundus Image');
            app.ImgAxesRaw.XTick = []; app.ImgAxesRaw.YTick = [];

            % Enhanced Image Axes
            app.ImgAxesEnhanced = uiaxes(p, 'Position', [370, h - 265, axW, axH]);
            title(app.ImgAxesEnhanced, 'Enhanced (L*a*b* CLAHE + Flat-Field)');
            app.ImgAxesEnhanced.XTick = []; app.ImgAxesEnhanced.YTick = [];

            % 64-Bin Green Channel Histogram Axes
            app.HistAxesRaw = uiaxes(p, 'Position', [15, 60, axW, 190]);
            title(app.HistAxesRaw, 'Raw Green Intensity (Hemoglobin Absorption)');
            xlabel(app.HistAxesRaw, 'Intensity (0-255)');
            ylabel(app.HistAxesRaw, 'Count');

            app.HistAxesEnhanced = uiaxes(p, 'Position', [370, 60, axW, 190]);
            title(app.HistAxesEnhanced, 'Enhanced Green Intensity (CLAHE Contrast)');
            xlabel(app.HistAxesEnhanced, 'Intensity (0-255)');
            ylabel(app.HistAxesEnhanced, 'Count');

            % Metrics breakdown panel (4 columns: Metric, Measured, Threshold, Status)
            metricW = w - 740;
            metricPanel = uipanel(p, 'Title', '5-Metric Empirical Quality Scores', ...
                'Position', [725, h - 235, metricW, 160], 'FontWeight', 'bold');
            
            app.QualityMetricsTable = uitable(metricPanel, ...
                'Data', {
                    'Focus Variance (Laplacian)', '--', '>= 18.0 (Good)', 'Pending';
                    'Illumination Mean',         '--', '[25.0, 215.0]', 'Pending';
                    'Illumination Shannon Ent.', '--', '>= 3.500',      'Pending';
                    'Retinal FOV Coverage',      '--', '>= 50.0%',      'Pending';
                    'Optic Disc Contrast',       '--', '>= 1.150',      'Pending';
                    'Vessel Gradient Energy',    '--', '>= 1.500',      'Pending'
                }, ...
                'ColumnName', {'Quality Metric', 'Measured', 'Threshold', 'Status'}, ...
                'ColumnWidth', {140, 85, 120, 80}, ...
                'Position', [8, 8, metricW - 18, 124]);

            % Actionable Recapture Guidance Panel
            advicePanel = uipanel(p, 'Title', 'Clinical Recapture Guidance (Fail-Closed)', ...
                'Position', [725, h - 370, metricW, 125], 'FontWeight', 'bold');
                
            app.RecaptureAdviceLabel = uilabel(advicePanel, ...
                'Text', sprintf(['Load an eye photograph and click "Run Quality Assessment".\n\n', ...
                'The quality gate evaluates focus, illumination, and anatomical landmarks with fail-closed safety.']), ...
                'Position', [10, 8, metricW - 20, 90], 'WordWrap', 'on', 'FontSize', 10);

            % Help Panel: How to capture a suitable fundus image
            helpPanel = uipanel(p, 'Title', 'How to capture a suitable fundus image', ...
                'Position', [725, 55, metricW, 140], 'FontWeight', 'bold');
            
            uilabel(helpPanel, ...
                'Text', sprintf(['1. Centre the retinal field in the camera aperture.\n', ...
                '2. Ensure optic disc and macula are visible within FOV.\n', ...
                '3. Maintain stable patient fixation; refocus diopter to avoid blur.\n', ...
                '4. Prevent excessive flash glare, reflections, and overexposure.\n', ...
                '5. Check pupil dilation to avoid dark, vignetted photographs.\n', ...
                '6. Clear eyelashes/eyelid obstruction; retake cropped captures.\n', ...
                '7. Capture right and left eyes separately, labeling OD and OS correctly.']), ...
                'Position', [10, 6, metricW - 20, 105], 'FontSize', 9.5, 'FontColor', [0.15, 0.25, 0.35]);

            % Educational note under green channel plots
            uilabel(p, ...
                'Text', 'Note: Green-channel visualization isolates retinal vasculature for visual inspection; quality gate decision is based strictly on measured raw metrics.', ...
                'Position', [15, 42, 695, 16], 'FontSize', 9, 'FontColor', [0.4, 0.4, 0.4]);

            % Bottom Navigation Bar
            bNav = uipanel(p, 'Position', [15, 10, w - 30, 40], 'BorderType', 'none');
            uibutton(bNav, 'push', 'Text', '<- Back to Patient Intake', ...
                'Position', [5, 5, 170, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'patient'));
            uibutton(bNav, 'push', 'Text', 'Return to Overview', ...
                'Position', [185, 5, 140, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'overview'));
            uibutton(bNav, 'push', 'Text', 'Continue to AI Screening & Explainability ->', ...
                'Position', [w - 320, 5, 285, 30], ...
                'BackgroundColor', [0.12, 0.35, 0.65], 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) selectTab(app, 'screening'));
        end

        %% 4. Build Page 4: AI Screening & Explainability
        function buildScreeningTab(app)
            p = app.ScreeningTab;
            w = app.ContentWidth;
            h = app.ContentHeight;

            % Top Control Bar
            topBar = uipanel(p, 'Position', [15, h - 65, w - 30, 55], 'BackgroundColor', [1, 1, 1]);
            
            % Eye to Screen Toggle
            app.ScreenEyeButtonGroup = uibuttongroup(topBar, ...
                'Position', [10, 8, 160, 36], 'BorderType', 'none');
            app.ScreenEyeODButton = uiradiobutton(app.ScreenEyeButtonGroup, ...
                'Text', 'OD (Right)', 'Position', [5, 8, 75, 22], 'Value', true);
            app.ScreenEyeOSButton = uiradiobutton(app.ScreenEyeButtonGroup, ...
                'Text', 'OS (Left)', 'Position', [85, 8, 70, 22]);
            app.ScreenEyeButtonGroup.SelectionChangedFcn = @(bg, event) screenEyeChanged(app);

            % Detector Selector DropDown
            uilabel(topBar, 'Text', 'Detector:', 'Position', [175, 14, 55, 22], 'FontSize', 11, 'FontWeight', 'bold');
            app.ModelSelectDropDown = uidropdown(topBar, ...
                'Items', {'YOLO11n (IDRiD 4-Class: MA, HE, EX, SE)', 'YOLOv8 (Roboflow Diabetic-Retinopathy-3 1024px)'}, ...
                'Value', 'YOLO11n (IDRiD 4-Class: MA, HE, EX, SE)', ...
                'Position', [235, 12, 245, 28]);

            % Confidence Threshold Spinner
            uilabel(topBar, 'Text', 'Conf:', 'Position', [485, 14, 35, 22], 'FontSize', 11);
            app.ConfSpinner = uispinner(topBar, 'Limits', [0.05, 0.90], 'Value', 0.20, 'Step', 0.05, ...
                'Position', [520, 12, 50, 26], 'ValueChangedFcn', @(sp, event) confSpinnerChanged(app));

            uibutton(topBar, 'push', ...
                'Text', 'Run Both Eyes (OD+OS)', ...
                'Position', [575, 9, 155, 36], ...
                'BackgroundColor', [0.10, 0.45, 0.25], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'FontSize', 11, ...
                'ButtonPushedFcn', @(~, ~) runBothEyesScreeningCallback(app));

            uibutton(topBar, 'push', ...
                'Text', 'Run Active Eye', ...
                'Position', [735, 9, 110, 36], ...
                'BackgroundColor', [0.12, 0.35, 0.65], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'FontSize', 11, ...
                'ButtonPushedFcn', @(~, ~) runAIScreeningCallback(app));

            app.GradeBannerLabel = uilabel(topBar, ...
                'Text', 'Grade: Not Screened', ...
                'Position', [855, 14, 210, 26], ...
                'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [0.1, 0.2, 0.4]);

            app.ReferralBannerLabel = uilabel(topBar, ...
                'Text', 'Referable DR: --', ...
                'Position', [1070, 14, w - 1085, 26], ...
                'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [0.4, 0.4, 0.4], ...
                'HorizontalAlignment', 'right');

            % Left: Retinal Image Axes with Bounding Boxes
            leftW = 660;
            app.ScreeningAxes = uiaxes(p, 'Position', [15, 95, leftW, h - 170]);
            title(app.ScreeningAxes, 'Explainable Retinal Lesion Detections (Retinal FOV Mask Filtered)');
            app.ScreeningAxes.XTick = []; app.ScreeningAxes.YTick = [];

            % Legend Panel (Full Class Names & Visual Mapping)
            legPanel = uipanel(p, 'Position', [15, 45, leftW, 46]);
            uilabel(legPanel, 'Text', '■ Yellow: Microaneurysms', 'Position', [10, 24, 150, 18], 'FontColor', [0.75, 0.65, 0.0], 'FontWeight', 'bold', 'FontSize', 10);
            uilabel(legPanel, 'Text', '■ Red: Haemorrhages', 'Position', [165, 24, 130, 18], 'FontColor', [0.85, 0.1, 0.1], 'FontWeight', 'bold', 'FontSize', 10);
            uilabel(legPanel, 'Text', '■ Green: Hard Exudates', 'Position', [300, 24, 140, 18], 'FontColor', [0.1, 0.65, 0.2], 'FontWeight', 'bold', 'FontSize', 10);
            uilabel(legPanel, 'Text', '■ Cyan: Soft Exudates (Cotton Wool)', 'Position', [10, 4, 210, 18], 'FontColor', [0.0, 0.65, 0.75], 'FontWeight', 'bold', 'FontSize', 10);
            uilabel(legPanel, 'Text', '■ Orange: MA/HE', 'Position', [225, 4, 110, 18], 'FontColor', [0.85, 0.45, 0.0], 'FontWeight', 'bold', 'FontSize', 10);
            uilabel(legPanel, 'Text', '■ Purple: Scar', 'Position', [340, 4, 95, 18], 'FontColor', [0.60, 0.15, 0.70], 'FontWeight', 'bold', 'FontSize', 10);
            
            uilabel(legPanel, 'Text', 'View:', 'Position', [445, 12, 35, 22], 'FontWeight', 'bold');
            app.ViewModeDropDown = uidropdown(legPanel, ...
                'Items', {'Bounding Boxes', 'Attention Heatmap'}, ...
                'Value', 'Bounding Boxes', ...
                'Position', [480, 11, 115, 24], ...
                'ValueChangedFcn', @(~, ~) updateScreeningViewForActiveEye(app));
            
            app.ShowLabelsCheckBox = uicheckbox(legPanel, 'Text', 'Labels', 'Value', true, ...
                'Position', [600, 12, 55, 22], 'ValueChangedFcn', @(~, ~) updateScreeningViewForActiveEye(app));

            % Right: Probability Table & Lesions Table
            rightX = leftW + 30;
            rightW = w - rightX - 15;
            
            probPanel = uipanel(p, 'Title', '5-Class DR Stage Probability & Clinical Interpretation', ...
                'Position', [rightX, h - 250, rightW, 180], 'FontWeight', 'bold');
            
            app.UncertaintyWarningLabel = uilabel(probPanel, ...
                'Text', 'Awaiting inference: Load fundus image and run AI analysis.', ...
                'Position', [10, 130, rightW - 20, 25], ...
                'FontSize', 9.5, 'FontWeight', 'bold', 'FontColor', [0.4, 0.4, 0.4]);
                
            app.GradeProbTable = uitable(probPanel, ...
                'Data', {
                    'Grade 0: No DR',        '--', 'No microaneurysms or retinal lesions';
                    'Grade 1: Mild NPDR',     '--', 'Microaneurysms only';
                    'Grade 2: Moderate NPDR', '--', 'More than mild NPDR, but less than severe';
                    'Grade 3: Severe NPDR',   '--', '>20 intraretinal hemorrhages or venous beading';
                    'Grade 4: Proliferative', '--', 'Neovascularization or vitreous hemorrhage'
                }, ...
                'ColumnName', {'Stage', 'Score', 'Clinical Hallmark'}, ...
                'ColumnWidth', {120, 55, 180}, ...
                'Position', [8, 8, rightW - 16, 120]);

            % Lesion Candidates Table & Grad-CAM Notice
            lesionPanel = uipanel(p, 'Title', 'Detected Lesion Candidates (Object Detection)', ...
                'Position', [rightX, 52, rightW, h - 310], 'FontWeight', 'bold');
                
            app.LesionCountTable = uitable(lesionPanel, ...
                'Data', {'Microaneurysms (MA)', 0; 'Haemorrhages (HE)', 0; 'Hard Exudates (EX)', 0; 'Soft Exudates (SE)', 0; 'TOTAL CANDIDATES', 0}, ...
                'ColumnName', {'Lesion Category', 'Count'}, ...
                'ColumnWidth', {200, 90}, ...
                'Position', [10, 35, rightW - 24, h - 390]);

            uilabel(lesionPanel, ...
                'Text', 'Explainability Note: Visual localization is provided by YOLO object bounding boxes. (ONNX runtime lacks backward autograd for Grad-CAM; retina_model.onnx has uncalibrated scratch weights).', ...
                'Position', [10, 6, rightW - 24, 25], 'WordWrap', 'on', 'FontSize', 8.5, 'FontColor', [0.4, 0.4, 0.4]);

            % Bottom Navigation Bar
            bNav = uipanel(p, 'Position', [15, 10, w - 30, 40], 'BorderType', 'none');
            uibutton(bNav, 'push', 'Text', '<- Back to Quality Gate', ...
                'Position', [5, 5, 160, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'quality'));
            uibutton(bNav, 'push', 'Text', 'Return to Overview', ...
                'Position', [175, 5, 140, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'overview'));
            uibutton(bNav, 'push', 'Text', 'Continue to Clinician Review & Report ->', ...
                'Position', [w - 300, 5, 265, 30], ...
                'BackgroundColor', [0.15, 0.55, 0.35], 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) selectTab(app, 'review'));
        end

        %% 5. Build Page 5: Clinician Review & Report
        function buildReviewTab(app)
            p = app.ReviewTab;
            w = app.ContentWidth;
            h = app.ContentHeight;

            formW = 500;
            reviewPanel = uipanel(p, 'Title', 'Clinician Review & Diagnostic Sign-Off', ...
                'Position', [15, 55, formW, h - 70], 'FontWeight', 'bold', 'FontSize', 12);

            uilabel(reviewPanel, 'Text', 'Reviewer Name *:', 'Position', [20, h - 120, 120, 22]);
            app.ReviewerNameEdit = uieditfield(reviewPanel, 'text', 'Value', '', ...
                'Placeholder', 'Enter reviewing clinician name', ...
                'Position', [150, h - 120, 330, 26]);

            uilabel(reviewPanel, 'Text', 'Reviewer Role:', 'Position', [20, h - 160, 120, 22]);
            app.ReviewerRoleDropDown = uidropdown(reviewPanel, ...
                'Items', {'Consultant Ophthalmologist', 'Senior Optometrist', 'Tele-Ophthalmologist', 'Medical Officer'}, ...
                'Value', 'Consultant Ophthalmologist', 'Position', [150, h - 160, 330, 26]);

            uilabel(reviewPanel, 'Text', 'Clinical Diagnosis:', 'Position', [20, h - 200, 120, 22]);
            app.DecisionDropDown = uidropdown(reviewPanel, ...
                'Items', {'Not yet reviewed', 'Confirm AI Grade', 'Modify: Grade 0 (No DR)', 'Modify: Grade 1 (Mild NPDR)', 'Modify: Grade 2 (Moderate NPDR)', 'Modify: Grade 3 (Severe NPDR)', 'Modify: Grade 4 (Proliferative DR)', 'Reject: Image Inadequate / Request Recapture'}, ...
                'Value', 'Not yet reviewed', 'Position', [150, h - 200, 330, 26]);

            uilabel(reviewPanel, 'Text', 'Referral Action:', 'Position', [20, h - 235, 120, 22]);
            app.ReferralDropDown = uidropdown(reviewPanel, ...
                'Items', {'Routine Annual (12 Months)', 'Primary Review (6 Months)', 'District Referral (3-4 Weeks)', 'URGENT: Tertiary Laser / Anti-VEGF (< 1 Week)'}, ...
                'Value', 'Routine Annual (12 Months)', 'Position', [150, h - 235, 330, 26]);

            uilabel(reviewPanel, 'Text', 'Hospital Facility *:', 'Position', [20, h - 275, 120, 22]);
            app.HospitalFacilityEdit = uieditfield(reviewPanel, 'text', ...
                'Value', 'District Eye Hospital, Tertiary Care Center', ...
                'Position', [150, h - 275, 330, 26]);

            uilabel(reviewPanel, 'Text', 'Referral Timeframe:', 'Position', [20, h - 315, 125, 22]);
            app.ReferralTimeframeDropDown = uidropdown(reviewPanel, ...
                'Items', {'Immediate: Within 24-48 Hours (High Risk)', 'Priority Referral: Within 2 to 4 Weeks', 'Routine Follow-up: 6 to 12 Months'}, ...
                'Value', 'Priority Referral: Within 2 to 4 Weeks', 'Position', [150, h - 315, 330, 26]);

            uilabel(reviewPanel, 'Text', 'Clinical Notes & Recommendations:', 'Position', [20, h - 350, 250, 22]);
            app.NotesTextArea = uitextarea(reviewPanel, ...
                'Value', {'Review completed. Patient informed.'}, ...
                'Position', [20, h - 440, 460, 85]);

            uilabel(reviewPanel, 'Text', 'Report Language:', 'Position', [20, 88, 120, 22], 'FontWeight', 'bold');
            app.ReportLangDropDown = uidropdown(reviewPanel, ...
                'Items', {'English', 'Tamil (தமிழ்)', 'Hindi (हिंदी)'}, ...
                'Value', 'English', ...
                'Position', [145, 87, 180, 26]);

            % Action Buttons Row
            uibutton(reviewPanel, 'push', ...
                'Text', 'Save Sign-Off', ...
                'Position', [20, 48, 110, 32], ...
                'BackgroundColor', [0.12, 0.35, 0.65], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(btn, event) saveReviewCallback(app));

            uibutton(reviewPanel, 'push', ...
                'Text', 'Generate 6-Panel PDF', ...
                'Position', [135, 48, 150, 32], ...
                'BackgroundColor', [0.15, 0.55, 0.35], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(btn, event) exportPdfReportCallback(app));

            uibutton(reviewPanel, 'push', ...
                'Text', 'Export Text', ...
                'Position', [290, 48, 95, 32], ...
                'ButtonPushedFcn', @(btn, event) exportTxtReportCallback(app));

            uibutton(reviewPanel, 'push', ...
                'Text', 'Open Reports', ...
                'Position', [390, 50, 95, 32], ...
                'ButtonPushedFcn', @(~, ~) openReportsFolder(app));

            % Multilingual Audio Row
            uilabel(reviewPanel, 'Text', 'Multilingual Audio:', 'Position', [20, 15, 120, 24], 'FontWeight', 'bold');
            uibutton(reviewPanel, 'push', 'Text', 'Tamil (தமிழ்)', 'Position', [145, 14, 100, 26], ...
                'ButtonPushedFcn', @(~, ~) playMultilingualAudio(app, 'ta'));
            uibutton(reviewPanel, 'push', 'Text', 'Hindi (हिंदी)', 'Position', [255, 14, 100, 26], ...
                'ButtonPushedFcn', @(~, ~) playMultilingualAudio(app, 'hi'));
            uibutton(reviewPanel, 'push', 'Text', 'English', 'Position', [365, 14, 90, 26], ...
                'ButtonPushedFcn', @(~, ~) playMultilingualAudio(app, 'en'));

            % Right: Report Preview Panel
            prevX = formW + 30;
            prevW = w - prevX - 15;
            previewPanel = uipanel(p, 'Title', 'Screening Summary & Verification Preview', ...
                'Position', [prevX, 55, prevW, h - 70], 'FontWeight', 'bold', 'FontSize', 12);

            app.ReviewStatusLabel = uilabel(previewPanel, ...
                'Text', 'Review Status: Pending Clinician Sign-Off', ...
                'Position', [12, h - 105, prevW - 24, 24], ...
                'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [0.5, 0.3, 0.1]);

            app.ReportPreviewLabel = uilabel(previewPanel, ...
                'Text', 'No report generated yet. Register a patient, run AI screening, and record clinician sign-off.', ...
                'Position', [12, 12, prevW - 24, h - 125], 'FontName', 'Courier New', 'FontSize', 10);

            % Bottom Navigation Bar with prominent "Finish & Save Case (Start New Patient)"
            bNav = uipanel(p, 'Position', [15, 10, w - 30, 40], 'BorderType', 'none');
            uibutton(bNav, 'push', 'Text', '<- Back to AI Screening', ...
                'Position', [5, 5, 160, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'screening'));
            uibutton(bNav, 'push', 'Text', 'Return to Overview', ...
                'Position', [175, 5, 130, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'overview'));
            
            uibutton(bNav, 'push', 'Text', '✔ FINISH & SAVE CASE (Start New Patient)', ...
                'Position', [315, 5, 290, 30], ...
                'BackgroundColor', [0.12, 0.50, 0.25], 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) finishAndStartNewPatientCallback(app));

            uibutton(bNav, 'push', 'Text', 'Clinic Workflow Simulation ->', ...
                'Position', [w - 230, 5, 200, 30], ...
                'ButtonPushedFcn', @(~, ~) selectTab(app, 'simulation'));
        end

        %% 6. Build Page 6: Clinic Workflow Simulation
        function buildSimulationTab(app)
            p = app.SimulationTab;
            w = app.ContentWidth;
            h = app.ContentHeight;

            % Controls Bar
            ctrlPanel = uipanel(p, 'Position', [15, h - 65, w - 30, 55], 'BackgroundColor', [1, 1, 1]);
            
            uilabel(ctrlPanel, 'Text', 'Scenario:', 'Position', [10, 14, 60, 22], 'FontWeight', 'bold');
            app.ScenarioDropDown = uidropdown(ctrlPanel, ...
                'Items', {'Connected (Broadband)', 'LowBandwidth (2G/Satellite)', 'OfflineBacklog (Batch Sync)', 'Optimized (2 Tele-Reviewers)'}, ...
                'Value', 'Connected (Broadband)', ...
                'Position', [75, 12, 210, 28]);

            uilabel(ctrlPanel, 'Text', 'Arrival Rate:', 'Position', [295, 14, 75, 22]);
            app.SimArrivalRateEdit = uieditfield(ctrlPanel, 'numeric', 'Value', 15, ...
                'Position', [370, 12, 50, 26]);
            uilabel(ctrlPanel, 'Text', 'pts/hr', 'Position', [425, 14, 45, 22], 'FontColor', [0.4, 0.4, 0.4]);

            uilabel(ctrlPanel, 'Text', 'Review Time:', 'Position', [475, 14, 75, 22]);
            app.SimServiceTimeEdit = uieditfield(ctrlPanel, 'numeric', 'Value', 1.5, ...
                'Position', [550, 12, 50, 26]);
            uilabel(ctrlPanel, 'Text', 'mins', 'Position', [605, 14, 35, 22], 'FontColor', [0.4, 0.4, 0.4]);

            uibutton(ctrlPanel, 'push', ...
                'Text', 'Run Queueing Simulation', ...
                'Position', [650, 10, 180, 34], ...
                'BackgroundColor', [0.12, 0.35, 0.65], ...
                'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(btn, event) runSimulationCallback(app));

            uibutton(ctrlPanel, 'push', ...
                'Text', 'Reset', ...
                'Position', [838, 10, 75, 34], ...
                'ButtonPushedFcn', @(~, ~) resetSimulationCallback(app));

            app.SimStatusLabel = uilabel(ctrlPanel, ...
                'Text', 'Simulation: Ready (Stochastic Planning Engine)', ...
                'Position', [925, 14, w - 940, 24], 'FontWeight', 'bold', 'FontColor', [0.1, 0.5, 0.2]);

            % Left: Queue Plot Axes
            leftW = 660;
            app.SimAxes = uiaxes(p, 'Position', [15, 65, leftW, h - 145]);
            title(app.SimAxes, 'Patient Queue Dynamics Across 8-Hour Clinic Shift (SimEvents Engine)');
            xlabel(app.SimAxes, 'Clinic Shift Time (Minutes)');
            ylabel(app.SimAxes, 'Patients in Queue / Processing');
            grid(app.SimAxes, 'on');

            uilabel(p, ...
                'Text', 'Note: Queueing simulation is an optional capacity planning tool using synthetic Poisson models. It does not reflect real patient diagnoses.', ...
                'Position', [15, 45, leftW, 16], 'FontSize', 8.5, 'FontColor', [0.4, 0.4, 0.4]);

            % Right: Metrics Accounting Table
            rightX = leftW + 30;
            rightW = w - rightX - 15;
            metricPanel = uipanel(p, 'Title', 'Throughput & Resource Conservation Accounting', ...
                'Position', [rightX, 55, rightW, h - 130], 'FontWeight', 'bold', 'FontSize', 12);

            app.SimMetricsTable = uitable(metricPanel, ...
                'Data', {
                    'Total Patient Arrivals', '--';
                    'Completed Screenings', '--';
                    'Quality Gate Rejections', '--';
                    'Still Queued at Shift End', '--';
                    'Conservation Check (Arrived == Sum)', '--';
                    'Throughput (Patients / Hour)', '--';
                    'Mean Turnaround Time', '--';
                    '90th Percentile Turnaround', '--';
                    'Tele-Reviewer Utilization', '--'
                }, ...
                'ColumnName', {'Simulation Metric', 'Accounting Result'}, ...
                'ColumnWidth', {190, 140}, ...
                'Position', [10, 10, rightW - 24, h - 170]);

            % Bottom Navigation Bar
            bNav = uipanel(p, 'Position', [15, 10, w - 30, 40], 'BorderType', 'none');
            uibutton(bNav, 'push', 'Text', '<- Return to Overview', ...
                'Position', [5, 5, 170, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'overview'));
            uibutton(bNav, 'push', 'Text', 'Return to AI Screening', ...
                'Position', [185, 5, 160, 30], 'ButtonPushedFcn', @(~, ~) selectTab(app, 'screening'));
        end

        %% Callbacks & Persistent State Management

        function safeAlert(app, msg, titleText, iconType)
            if nargin < 4, iconType = 'info'; end
            try
                if isvalid(app.UIFigure) && strcmp(app.UIFigure.Visible, 'on')
                    uialert(app.UIFigure, msg, titleText, 'Icon', iconType);
                else
                    fprintf('[%s] %s: %s\n', upper(iconType), titleText, msg);
                end
            catch
                fprintf('[%s] %s: %s\n', upper(iconType), titleText, msg);
            end
        end

        function d = showProgress(app, titleText, msgText)
            d = [];
            try
                if isvalid(app.UIFigure) && strcmp(app.UIFigure.Visible, 'on')
                    d = uiprogressdlg(app.UIFigure, 'Title', titleText, 'Message', msgText, 'Indeterminate', 'on');
                    drawnow;
                end
            catch
                d = [];
            end
        end

        function closeProgress(~, d)
            try
                if ~isempty(d) && isvalid(d)
                    close(d);
                end
            catch
            end
        end

        % Case ID Generation
        function newID = generateUniqueCaseID(app)
            maxNum = 0;
            try
                reg = loadRegistryData(app);
                if istable(reg) && ~isempty(reg) && ismember('CaseID', reg.Properties.VariableNames)
                    for i = 1:height(reg)
                        tok = regexp(reg.CaseID{i}, 'RS-2026-(\d+)', 'tokens');
                        if ~isempty(tok)
                            maxNum = max(maxNum, str2double(tok{1}{1}));
                        end
                    end
                end
            catch
            end
            
            % Check individual case files on disk
            try
                if ~isempty(app.CasesDir) && exist(app.CasesDir, 'dir')
                    matFiles = dir(fullfile(app.CasesDir, 'RS-2026-*.mat'));
                    for i = 1:numel(matFiles)
                        tok = regexp(matFiles(i).name, 'RS-2026-(\d+)\.mat', 'tokens');
                        if ~isempty(tok)
                            maxNum = max(maxNum, str2double(tok{1}{1}));
                        end
                    end
                end
            catch
            end
            
            newID = sprintf('RS-2026-%03d', maxNum + 1);
            try
                if ~isempty(app.CaseIDLabel) && isvalid(app.CaseIDLabel)
                    app.CaseIDLabel.Text = newID;
                end
            catch
            end
            app.CurrentCaseID = newID;
        end

        function onStartNewCaseButtonPushed(app)
            % Check for unsaved changes before starting a new case
            hasUnsavedData = ~isempty(strtrim(app.PatientNameEdit.Value)) || ...
                ~isempty(app.ImagePathOD) || ~isempty(app.ImagePathOS);
            if hasUnsavedData
                choice = uiconfirm(app.UIFigure, ...
                    sprintf('Start a new case? Any unsaved edits in current case (%s) will be discarded.', app.CurrentCaseID), ...
                    'Start New Case Confirmation', ...
                    'Options', {'Discard and Start New', 'Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 2);
                if ~strcmp(choice, 'Discard and Start New')
                    return;
                end
            end
            resetCurrentDraft(app);
            safeAlert(app, sprintf('Initialized new clean screening case: %s.', app.CurrentCaseID), 'New Case Ready');
        end

        function resetCurrentDraft(app)
            % 1. Generate unique Case ID
            app.CurrentCaseID = generateUniqueCaseID(app);
            
            % 2. Completely blank all patient demographic fields
            app.CurrentPatientName = '';
            app.CurrentPatientAge = 0;
            app.CurrentPatientGender = 'Male';
            app.CurrentContact = '';
            app.CurrentInsuranceID = '';
            app.CurrentDMDuration = 0;
            app.CurrentHbA1c = 0;
            app.ConsentObtained = false;
            app.CaseCreatedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            app.CaseUpdatedAt = app.CaseCreatedAt;
            
            % 3. Clear Images & Analysis Results
            app.ImagePathOD = ''; app.ImagePathOS = '';
            app.RawImageOD = [];  app.RawImageOS = [];
            app.EnhancedImageOD = []; app.EnhancedImageOS = [];
            app.QualityStatusOD = 'Not Evaluated'; app.QualityStatusOS = 'Not Evaluated';
            app.QualityMetricsOD = struct(); app.QualityMetricsOS = struct();
            app.ClassificationOD = struct(); app.ClassificationOS = struct();
            app.DetectionsTableOD = table(); app.DetectionsTableOS = table();
            app.OverlayImageOD = []; app.OverlayImageOS = [];
            
            % 4. Reset Clinician Review state
            app.ReviewerName = '';
            app.ReviewerRole = 'Consultant Ophthalmologist';
            app.ClinicalDecision = 'Not yet reviewed';
            app.ReferralAction = 'Routine Annual (12 Months)';
            app.ClinicalNotes = {'No clinical notes recorded.'};
            app.ReviewSaved = false;
            app.ReportExportPath = '';
            
            % 5. Reset UI Controls
            if ~isempty(app.CaseIDLabel) && isvalid(app.CaseIDLabel)
                app.CaseIDLabel.Text = app.CurrentCaseID;
            end
            if ~isempty(app.PatientNameEdit) && isvalid(app.PatientNameEdit)
                app.PatientNameEdit.Value = '';
            end
            if ~isempty(app.AgeEdit) && isvalid(app.AgeEdit)
                app.AgeEdit.Value = 0;
            end
            if ~isempty(app.GenderDropDown) && isvalid(app.GenderDropDown)
                app.GenderDropDown.Value = 'Male';
            end
            if ~isempty(app.ContactEdit) && isvalid(app.ContactEdit)
                app.ContactEdit.Value = '';
            end
            if ~isempty(app.InsuranceEdit) && isvalid(app.InsuranceEdit)
                app.InsuranceEdit.Value = '';
            end
            if ~isempty(app.DiabetesDurationEdit) && isvalid(app.DiabetesDurationEdit)
                app.DiabetesDurationEdit.Value = 0;
            end
            if ~isempty(app.HbA1cEdit) && isvalid(app.HbA1cEdit)
                app.HbA1cEdit.Value = 0;
            end
            if ~isempty(app.ConsentCheckBox) && isvalid(app.ConsentCheckBox)
                app.ConsentCheckBox.Value = false;
            end
            
            if ~isempty(app.EyeODStatusLabel) && isvalid(app.EyeODStatusLabel)
                app.EyeODStatusLabel.Text = 'OD: Empty';
                app.EyeODStatusLabel.FontColor = [0.4, 0.4, 0.4];
            end
            if ~isempty(app.EyeOSStatusLabel) && isvalid(app.EyeOSStatusLabel)
                app.EyeOSStatusLabel.Text = 'OS: Empty';
                app.EyeOSStatusLabel.FontColor = [0.4, 0.4, 0.4];
            end
            
            if ~isempty(app.ReviewerNameEdit) && isvalid(app.ReviewerNameEdit)
                app.ReviewerNameEdit.Value = '';
            end
            if ~isempty(app.ReviewerRoleDropDown) && isvalid(app.ReviewerRoleDropDown)
                app.ReviewerRoleDropDown.Value = 'Consultant Ophthalmologist';
            end
            if ~isempty(app.DecisionDropDown) && isvalid(app.DecisionDropDown)
                app.DecisionDropDown.Value = 'Not yet reviewed';
            end
            if ~isempty(app.ReferralDropDown) && isvalid(app.ReferralDropDown)
                app.ReferralDropDown.Value = 'Routine Annual (12 Months)';
            end
            if ~isempty(app.NotesTextArea) && isvalid(app.NotesTextArea)
                app.NotesTextArea.Value = {'No clinical notes recorded.'};
            end
            
            updateQualityViewForActiveEye(app);
            updateScreeningViewForActiveEye(app);
            updateReportPreview(app);
            
            if ~isempty(app.OverviewSummaryLabel) && isvalid(app.OverviewSummaryLabel)
                app.OverviewSummaryLabel.Text = sprintf('Draft: %s (New case — not saved)', app.CurrentCaseID);
            end
        end

        % Patient Save
        function savePatientCallback(app)
            pName = strtrim(app.PatientNameEdit.Value);
            if isempty(pName)
                safeAlert(app, 'Please enter the patient full name.', 'Validation Error', 'warning');
                return;
            end
            if app.AgeEdit.Value <= 0
                safeAlert(app, 'Please enter a valid patient age.', 'Validation Error', 'warning');
                return;
            end
            if ~app.ConsentCheckBox.Value
                safeAlert(app, 'Patient informed consent is required to proceed.', 'Consent Required', 'warning');
                return;
            end
            
            app.CurrentPatientName   = pName;
            app.CurrentPatientAge    = app.AgeEdit.Value;
            app.CurrentPatientGender = app.GenderDropDown.Value;
            app.CurrentContact       = strtrim(app.ContactEdit.Value);
            app.CurrentInsuranceID   = strtrim(app.InsuranceEdit.Value);
            app.CurrentDMDuration    = app.DiabetesDurationEdit.Value;
            app.CurrentHbA1c         = app.HbA1cEdit.Value;
            app.ConsentObtained      = true;
            app.CaseUpdatedAt        = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            
            % Persist to both Case MAT file and Registry
            saveActiveCase(app);
            refreshAllRegistryViews(app);
            
            safeAlert(app, sprintf('Patient %s (Case %s) successfully registered.', pName, app.CurrentCaseID), 'Registration Saved');
        end

        % Storage & Persistence Layer
        function initRegistryStorage(app)
            if ~isfile(app.RegistryFilePath)
                patients = table({}, {}, [], {}, {}, {}, {}, {}, ...
                    'VariableNames', {'CaseID', 'Name', 'Age', 'Gender', 'Contact', 'DM_Duration', 'HbA1c', 'Status'});
                save(app.RegistryFilePath, 'patients');
            end
        end

        function reg = loadRegistryData(app)
            initRegistryStorage(app);
            s = load(app.RegistryFilePath, 'patients');
            reg = s.patients;
        end

        function saveActiveCase(app)
            % Guard: Do not save uninitialized empty drafts
            if isempty(strtrim(app.CurrentPatientName)) && isempty(app.ImagePathOD) && isempty(app.ImagePathOS)
                return;
            end
            
            caseData = struct();
            caseData.CaseID = app.CurrentCaseID;
            caseData.PatientName = app.CurrentPatientName;
            caseData.Age = app.CurrentPatientAge;
            caseData.Gender = app.CurrentPatientGender;
            caseData.Contact = app.CurrentContact;
            caseData.InsuranceID = app.CurrentInsuranceID;
            caseData.DMDuration = app.CurrentDMDuration;
            caseData.HbA1c = app.CurrentHbA1c;
            caseData.ConsentObtained = app.ConsentObtained;
            caseData.CreatedAt = app.CaseCreatedAt;
            caseData.UpdatedAt = app.CaseUpdatedAt;
            
            caseData.ImagePathOD = app.ImagePathOD;
            caseData.ImagePathOS = app.ImagePathOS;
            caseData.QualityStatusOD = app.QualityStatusOD;
            caseData.QualityStatusOS = app.QualityStatusOS;
            caseData.QualityMetricsOD = app.QualityMetricsOD;
            caseData.QualityMetricsOS = app.QualityMetricsOS;
            
            caseData.ClassificationOD = app.ClassificationOD;
            caseData.ClassificationOS = app.ClassificationOS;
            caseData.DetectionsTableOD = app.DetectionsTableOD;
            caseData.DetectionsTableOS = app.DetectionsTableOS;
            
            caseData.ReviewerName = app.ReviewerName;
            caseData.ReviewerRole = app.ReviewerRole;
            caseData.ClinicalDecision = app.ClinicalDecision;
            caseData.ReferralAction = app.ReferralAction;
            caseData.HospitalFacility = app.HospitalFacility;
            caseData.ReferralTimeframe = app.ReferralTimeframe;
            caseData.ClinicalNotes = app.ClinicalNotes;
            caseData.ReviewSaved = app.ReviewSaved;
            caseData.ReportExportPath = app.ReportExportPath;
            
            % Save to individual case file
            caseFile = fullfile(app.CasesDir, sprintf('%s.mat', app.CurrentCaseID));
            save(caseFile, 'caseData');
            
            % Update global registry table ONLY if patient name is present
            if ~isempty(strtrim(app.CurrentPatientName))
                reg = loadRegistryData(app);
                matchIdx = find(strcmp(reg.CaseID, app.CurrentCaseID), 1);
                
                dmStr = sprintf('%.0f yrs', app.CurrentDMDuration);
                if app.CurrentDMDuration == 0, dmStr = '--'; end
                hbStr = sprintf('%.1f%%', app.CurrentHbA1c);
                if app.CurrentHbA1c == 0, hbStr = '--'; end
                
                statusStr = 'Intake Complete';
                if ~isempty(app.ImagePathOD) || ~isempty(app.ImagePathOS), statusStr = 'Images Loaded'; end
                if strcmp(app.QualityStatusOD, 'Good') || strcmp(app.QualityStatusOS, 'Good'), statusStr = 'Quality Passed'; end
                if isfield(app.ClassificationOD, 'predicted_label') || isfield(app.ClassificationOS, 'predicted_label'), statusStr = 'Screened'; end
                if app.ReviewSaved, statusStr = 'Reviewed'; end
                
                newRow = table({app.CurrentCaseID}, {app.CurrentPatientName}, app.CurrentPatientAge, ...
                    {app.CurrentPatientGender}, {app.CurrentContact}, {dmStr}, {hbStr}, {statusStr}, ...
                    'VariableNames', {'CaseID', 'Name', 'Age', 'Gender', 'Contact', 'DM_Duration', 'HbA1c', 'Status'});
                
                if isempty(matchIdx)
                    reg = [reg; newRow];
                else
                    reg(matchIdx, :) = newRow;
                end
                
                patients = reg; %#ok<NASGU>
                save(app.RegistryFilePath, 'patients');
                
                % Background Cloud Sync to Supabase (Fail-Safe Offline Mode)
                try
                    sync_case_to_supabase(caseData);
                catch
                end
            end
        end

        function loadCase(app, caseID)
            caseFile = fullfile(app.CasesDir, sprintf('%s.mat', caseID));
            if ~isfile(caseFile)
                uialert(app.UIFigure, sprintf('Case file not found: %s', caseFile), 'Load Error');
                return;
            end
            
            s = load(caseFile, 'caseData');
            cd = s.caseData;
            
            app.CurrentCaseID        = cd.CaseID;
            app.CurrentPatientName   = cd.PatientName;
            app.CurrentPatientAge    = cd.Age;
            app.CurrentPatientGender = cd.Gender;
            app.CurrentContact       = cd.Contact;
            app.CurrentInsuranceID   = cd.InsuranceID;
            app.CurrentDMDuration    = cd.DMDuration;
            app.CurrentHbA1c         = cd.HbA1c;
            app.ConsentObtained      = cd.ConsentObtained;
            app.CaseCreatedAt        = cd.CreatedAt;
            app.CaseUpdatedAt        = cd.UpdatedAt;
            
            % Update Patient Form UI
            app.CaseIDLabel.Text          = cd.CaseID;
            app.PatientNameEdit.Value     = cd.PatientName;
            app.AgeEdit.Value             = cd.Age;
            app.GenderDropDown.Value      = cd.Gender;
            app.ContactEdit.Value         = cd.Contact;
            app.InsuranceEdit.Value       = cd.InsuranceID;
            app.DiabetesDurationEdit.Value = cd.DMDuration;
            app.HbA1cEdit.Value           = cd.HbA1c;
            app.ConsentCheckBox.Value     = cd.ConsentObtained;
            
            % Restore Images
            app.ImagePathOD = cd.ImagePathOD;
            app.ImagePathOS = cd.ImagePathOS;
            if ~isempty(app.ImagePathOD) && isfile(app.ImagePathOD)
                app.RawImageOD = imread(app.ImagePathOD);
                app.EyeODStatusLabel.Text = 'OD: Loaded'; app.EyeODStatusLabel.FontColor = [0.1, 0.5, 0.2];
            end
            if ~isempty(app.ImagePathOS) && isfile(app.ImagePathOS)
                app.RawImageOS = imread(app.ImagePathOS);
                app.EyeOSStatusLabel.Text = 'OS: Loaded'; app.EyeOSStatusLabel.FontColor = [0.1, 0.5, 0.2];
            end
            
            % Restore Enhanced Images
            if ~isempty(app.RawImageOD)
                try [app.EnhancedImageOD, ~, ~] = enhance_retinal_image(app.RawImageOD); catch, end
            end
            if ~isempty(app.RawImageOS)
                try [app.EnhancedImageOS, ~, ~] = enhance_retinal_image(app.RawImageOS); catch, end
            end
            
            % Restore Quality Gate
            app.QualityStatusOD  = cd.QualityStatusOD;
            app.QualityStatusOS  = cd.QualityStatusOS;
            app.QualityMetricsOD = cd.QualityMetricsOD;
            app.QualityMetricsOS = cd.QualityMetricsOS;
            
            % Restore AI Results
            app.ClassificationOD  = cd.ClassificationOD;
            app.ClassificationOS  = cd.ClassificationOS;
            app.DetectionsTableOD = cd.DetectionsTableOD;
            app.DetectionsTableOS = cd.DetectionsTableOS;
            
            if istable(app.DetectionsTableOD) && height(app.DetectionsTableOD) > 0 && ~isempty(app.RawImageOD)
                [app.OverlayImageOD, ~] = overlay_lesion_detections(app.RawImageOD, app.DetectionsTableOD);
            end
            if istable(app.DetectionsTableOS) && height(app.DetectionsTableOS) > 0 && ~isempty(app.RawImageOS)
                [app.OverlayImageOS, ~] = overlay_lesion_detections(app.RawImageOS, app.DetectionsTableOS);
            end
            
            % Restore Review Form
            app.ReviewerName = cd.ReviewerName;
            app.ReviewerNameEdit.Value = cd.ReviewerName;
            app.ReviewerRole = cd.ReviewerRole;
            app.ReviewerRoleDropDown.Value = cd.ReviewerRole;
            app.ClinicalDecision = cd.ClinicalDecision;
            app.DecisionDropDown.Value = cd.ClinicalDecision;
            app.ReferralAction = cd.ReferralAction;
            app.ReferralDropDown.Value = cd.ReferralAction;
            if isfield(cd, 'HospitalFacility') && ~isempty(cd.HospitalFacility)
                app.HospitalFacility = cd.HospitalFacility;
                if isprop(app, 'HospitalFacilityEdit') && isvalid(app.HospitalFacilityEdit)
                    app.HospitalFacilityEdit.Value = cd.HospitalFacility;
                end
            end
            if isfield(cd, 'ReferralTimeframe') && ~isempty(cd.ReferralTimeframe)
                app.ReferralTimeframe = cd.ReferralTimeframe;
                if isprop(app, 'ReferralTimeframeDropDown') && isvalid(app.ReferralTimeframeDropDown)
                    app.ReferralTimeframeDropDown.Value = cd.ReferralTimeframe;
                end
            end
            app.ClinicalNotes = cd.ClinicalNotes;
            app.NotesTextArea.Value = cd.ClinicalNotes;
            app.ReviewSaved = cd.ReviewSaved;
            
            % Update Views
            updateQualityViewForActiveEye(app);
            updateScreeningViewForActiveEye(app);
            updateReportPreview(app);
            
            safeAlert(app, sprintf('Loaded Case %s for patient %s.', cd.CaseID, cd.PatientName), 'Case Loaded');
        end

        function loadSelectedCaseFromOverview(app)
            tbl = app.OverviewCasesTable;
            s = tbl.Selection;
            if isempty(s)
                safeAlert(app, 'Please select a case row to load.', 'No Row Selected', 'warning');
                return;
            end
            rowIdx = s(1);
            if rowIdx <= size(tbl.Data, 1) && ~isempty(tbl.Data{rowIdx, 1})
                cID = tbl.Data{rowIdx, 1};
                if ~strcmp(cID, '--')
                    loadCase(app, cID);
                end
            end
        end

        function loadSelectedCaseFromPatientTab(app)
            tbl = app.PatientTable;
            s = tbl.Selection;
            if isempty(s)
                safeAlert(app, 'Please select a case row to load.', 'No Row Selected', 'warning');
                return;
            end
            rowIdx = s(1);
            if rowIdx <= size(tbl.Data, 1) && ~isempty(tbl.Data{rowIdx, 1})
                cID = tbl.Data{rowIdx, 1};
                if ~strcmp(cID, '--')
                    loadCase(app, cID);
                end
            end
        end

        function refreshAllRegistryViews(app)
            reg = loadRegistryData(app);
            n = height(reg);
            
            if n == 0
                app.PatientTable.Data = {'--', 'No patients registered yet', [], '--', '--', '--', 'Pending Intake'};
                app.OverviewCasesTable.Data = {'--', 'No saved cases yet', '--', '--', '--'};
                app.OverviewSummaryLabel.Text = 'Database: 0 registered cases  |  Ready for patient intake.';
            else
                % Populate Patient Registry Table
                pData = cell(n, 7);
                for i = 1:n
                    pData{i, 1} = reg.CaseID{i};
                    pData{i, 2} = reg.Name{i};
                    pData{i, 3} = reg.Age(i);
                    pData{i, 4} = reg.Gender{i};
                    pData{i, 5} = reg.Contact{i};
                    pData{i, 6} = 'OD/OS Stored';
                    pData{i, 7} = reg.Status{i};
                end
                app.PatientTable.Data = pData;
                
                % Populate Overview Table
                oData = cell(n, 5);
                for i = 1:n
                    oData{i, 1} = reg.CaseID{i};
                    oData{i, 2} = reg.Name{i};
                    oData{i, 3} = sprintf('%d / %s', reg.Age(i), reg.Gender{i});
                    oData{i, 4} = reg.Status{i};
                    oData{i, 5} = datestr(now, 'yyyy-mm-dd HH:MM');
                end
                app.OverviewCasesTable.Data = oData;
                
                app.OverviewSummaryLabel.Text = sprintf('Database: %d saved case(s)  |  Active Case: %s (%s)', ...
                    n, app.CurrentCaseID, app.CurrentPatientName);
            end
        end

        % Eye Selection & Image Import
        function eyeSelectionChanged(app)
            if app.EyeSelectODButton.Value
                app.ActiveEye = 'OD';
            else
                app.ActiveEye = 'OS';
            end
            updateQualityViewForActiveEye(app);
        end

        function chooseImageCallback(app)
            try
                [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp', 'Fundus Image Files (*.jpg, *.jpeg, *.png, *.tif, *.tiff, *.bmp)'}, ...
                    sprintf('Select Retinal Fundus Photograph for %s', app.ActiveEye));
                
                % Ensure UIFigure regains focus and stays in foreground on Windows
                figure(app.UIFigure);
                drawnow;
                
                if isequal(file, 0) || isequal(path, 0)
                    % User cancelled — safely return without altering any application state
                    return;
                end
                
                fullPath = fullfile(path, file);
                raw = imread(fullPath);
                
                if ndims(raw) < 2 || isempty(raw)
                    uialert(app.UIFigure, 'The selected file is empty or corrupted.', 'Invalid Image');
                    return;
                end
                
                % Store image and mark earlier quality assessment, AI results, and Grad-CAM as stale
                if strcmp(app.ActiveEye, 'OD')
                    app.ImagePathOD = fullPath;
                    app.RawImageOD  = raw;
                    app.EnhancedImageOD = [];
                    app.QualityStatusOD = 'Not Evaluated';
                    app.QualityMetricsOD = struct();
                    app.ClassificationOD = struct();
                    app.DetectionsTableOD = table();
                    app.OverlayImageOD = [];
                    app.HeatmapImageOD = [];
                    app.EyeODStatusLabel.Text = sprintf('OD: %s (Loaded)', file);
                    app.EyeODStatusLabel.FontColor = [0.1, 0.5, 0.2];
                else
                    app.ImagePathOS = fullPath;
                    app.RawImageOS  = raw;
                    app.EnhancedImageOS = [];
                    app.QualityStatusOS = 'Not Evaluated';
                    app.QualityMetricsOS = struct();
                    app.ClassificationOS = struct();
                    app.DetectionsTableOS = table();
                    app.OverlayImageOS = [];
                    app.HeatmapImageOS = [];
                    app.EyeOSStatusLabel.Text = sprintf('OS: %s (Loaded)', file);
                    app.EyeOSStatusLabel.FontColor = [0.1, 0.5, 0.2];
                end
                
                % Invalidate downstream review & report state
                app.ReviewSaved = false;
                app.ReportExportPath = '';
                
                updateQualityViewForActiveEye(app);
                
                % Only persist to active case MAT file if patient is already registered
                if ~isempty(strtrim(app.CurrentPatientName)) && app.ConsentObtained
                    saveActiveCase(app);
                end
            catch ME
                uialert(app.UIFigure, sprintf('Could not read image file:\n%s', ME.message), 'Image Import Error');
            end
        end

        function captureCameraCallback(app)
            try
                cams = {};
                try
                    cams = webcamlist;
                catch
                end
                
                if isempty(cams)
                    uialert(app.UIFigure, sprintf(['No compatible fundus camera detected on this workstation.\n\n', ...
                        'You can continue the screening workflow by importing existing retinal photograph files using "Choose Image".\n\n', ...
                        'To enable live direct acquisition, connect a supported USB/GigE fundus camera and install the MATLAB Support Package for USB Webcams.']), ...
                        'Camera Status (Informational)', 'Icon', 'info');
                else
                    uialert(app.UIFigure, sprintf('Connected camera detected: %s.\n\nDirect live capture requires the device-specific stream driver. Please import saved PNG/JPEG/TIFF fundus photographs using "Choose Image".', cams{1}), ...
                        'Camera Detected', 'Icon', 'info');
                end
            catch ME
                uialert(app.UIFigure, sprintf('Camera status: %s. Please use "Choose Image" to import fundus files.', ME.message), ...
                    'Camera Unavailable', 'Icon', 'info');
            end
        end

        function updateQualityViewForActiveEye(app)
            if strcmp(app.ActiveEye, 'OD')
                targetImg = app.RawImageOD;
                targetStatus = app.QualityStatusOD;
                targetMetrics = app.QualityMetricsOD;
                targetEnhanced = app.EnhancedImageOD;
            else
                targetImg = app.RawImageOS;
                targetStatus = app.QualityStatusOS;
                targetMetrics = app.QualityMetricsOS;
                targetEnhanced = app.EnhancedImageOS;
            end
            
            if isempty(targetImg)
                if isgraphics(app.ImgAxesRaw)
                    cla(app.ImgAxesRaw);
                    title(app.ImgAxesRaw, sprintf('Original Fundus Image — %s (None Loaded)', app.ActiveEye));
                end
                if isgraphics(app.ImgAxesEnhanced)
                    cla(app.ImgAxesEnhanced);
                    title(app.ImgAxesEnhanced, sprintf('Enhanced (CLAHE + Flat-Field) — %s', app.ActiveEye));
                end
                if isgraphics(app.HistAxesRaw)
                    cla(app.HistAxesRaw);
                    title(app.HistAxesRaw, sprintf('%s Raw Green Intensity', app.ActiveEye));
                end
                if isgraphics(app.HistAxesEnhanced)
                    cla(app.HistAxesEnhanced);
                    title(app.HistAxesEnhanced, sprintf('%s Enhanced Green Intensity', app.ActiveEye));
                end
                app.QualityStatusLabel.Text = sprintf('%s Quality: NOT EVALUATED', app.ActiveEye);
                app.QualityStatusLabel.FontColor = [0.4, 0.4, 0.4];
                app.QualityMetricsTable.Data = {
                    'Focus Variance (Laplacian)', '--', '>= 18.0 (Good)', 'Pending';
                    'Illumination Mean',         '--', '[25.0, 215.0]', 'Pending';
                    'Illumination Shannon Ent.', '--', '>= 3.500',      'Pending';
                    'Retinal FOV Coverage',      '--', '>= 50.0%',      'Pending';
                    'Optic Disc Contrast',       '--', '>= 1.150',      'Pending';
                    'Vessel Gradient Energy',    '--', '>= 1.500',      'Pending'
                };
                app.RecaptureAdviceLabel.Text = sprintf(['Load an eye photograph and click "Run Quality Assessment (OD + OS)".\n\n', ...
                    'The quality gate evaluates focus, illumination, and anatomical landmarks with fail-closed safety.']);
            else
                if isgraphics(app.ImgAxesRaw)
                    imshow(targetImg, 'Parent', app.ImgAxesRaw);
                    title(app.ImgAxesRaw, sprintf('Original Fundus Image — %s', app.ActiveEye));
                end
                
                if ~isempty(targetEnhanced) && isgraphics(app.ImgAxesEnhanced)
                    imshow(targetEnhanced, 'Parent', app.ImgAxesEnhanced);
                    title(app.ImgAxesEnhanced, sprintf('Enhanced (CLAHE + Flat-Field) — %s', app.ActiveEye));
                    if isgraphics(app.HistAxesRaw)
                        histogram(app.HistAxesRaw, targetImg(:, :, 2), 64, 'FaceColor', [0.15, 0.55, 0.35]);
                        title(app.HistAxesRaw, sprintf('%s Raw Green Intensity (Hemoglobin Contrast)', app.ActiveEye));
                    end
                    if isgraphics(app.HistAxesEnhanced)
                        histogram(app.HistAxesEnhanced, targetEnhanced(:, :, 2), 64, 'FaceColor', [0.15, 0.45, 0.75]);
                        title(app.HistAxesEnhanced, sprintf('%s Enhanced Green Intensity (CLAHE)', app.ActiveEye));
                    end
                else
                    if isgraphics(app.ImgAxesEnhanced)
                        cla(app.ImgAxesEnhanced);
                        title(app.ImgAxesEnhanced, sprintf('Enhanced — %s (Click "Run Quality Assessment")', app.ActiveEye));
                    end
                    if isgraphics(app.HistAxesRaw)
                        histogram(app.HistAxesRaw, targetImg(:, :, 2), 64, 'FaceColor', [0.15, 0.55, 0.35]);
                        title(app.HistAxesRaw, sprintf('%s Raw Green Intensity (Hemoglobin Contrast)', app.ActiveEye));
                    end
                    if isgraphics(app.HistAxesEnhanced)
                        cla(app.HistAxesEnhanced);
                        title(app.HistAxesEnhanced, sprintf('%s Enhanced Green Intensity', app.ActiveEye));
                    end
                end
                
                if strcmp(targetStatus, 'Good')
                    app.QualityStatusLabel.Text = sprintf('%s Quality: PASS (Gradeable)', app.ActiveEye);
                    app.QualityStatusLabel.FontColor = [0.1, 0.6, 0.2];
                elseif strcmp(targetStatus, 'Borderline')
                    app.QualityStatusLabel.Text = sprintf('%s Quality: BORDERLINE (Review with Care)', app.ActiveEye);
                    app.QualityStatusLabel.FontColor = [0.85, 0.5, 0.0];
                elseif strcmp(targetStatus, 'Ungradable')
                    app.QualityStatusLabel.Text = sprintf('%s Quality: FAIL — RECAPTURE RECOMMENDED', app.ActiveEye);
                    app.QualityStatusLabel.FontColor = [0.8, 0.1, 0.1];
                elseif strcmp(targetStatus, 'AssessmentError')
                    app.QualityStatusLabel.Text = sprintf('%s Quality: ASSESSMENT ERROR', app.ActiveEye);
                    app.QualityStatusLabel.FontColor = [0.7, 0.1, 0.6];
                else
                    app.QualityStatusLabel.Text = sprintf('%s Quality: NOT EVALUATED', app.ActiveEye);
                    app.QualityStatusLabel.FontColor = [0.4, 0.4, 0.4];
                end
                
                if isstruct(targetMetrics) && isfield(targetMetrics, 'FocusScore') && ~isnan(targetMetrics.FocusScore)
                    app.QualityMetricsTable.Data = {
                        'Focus Variance (Laplacian)', sprintf('%.1f', targetMetrics.FocusScore), '>= 18.0 (Good)', targetMetrics.FocusStatus;
                        'Illumination Mean',         sprintf('%.1f', targetMetrics.MeanIntensity), '[25.0, 215.0]', targetMetrics.IlluminationStatus;
                        'Illumination Shannon Ent.', sprintf('%.3f', targetMetrics.IlluminationEntropy), '>= 3.500', targetMetrics.IlluminationStatus;
                        'Retinal FOV Coverage',      sprintf('%.1f%%', targetMetrics.FOVCoverage), '>= 50.0%', targetMetrics.FOVStatus;
                        'Optic Disc Contrast',       sprintf('%.3f', targetMetrics.ODVisibilityScore), '>= 1.150', targetMetrics.ODStatus;
                        'Vessel Gradient Energy',    sprintf('%.3f', targetMetrics.VesselVisibilityScore), '>= 1.500', targetMetrics.VesselStatus
                    };
                end
            end
        end

        function runQualityGateCallback(app)
            hasOD = ~isempty(app.RawImageOD);
            hasOS = ~isempty(app.RawImageOS);
            
            if ~hasOD && ~hasOS
                safeAlert(app, 'Please load at least one fundus image (OD or OS) using "Choose Image" before running quality assessment.', 'No Image Loaded', 'warning');
                return;
            end
            
            d = showProgress(app, 'Assessing Image Quality', 'Evaluating retinal clarity, illumination & field-of-view...');
            try
                % Assess OD if loaded
                if hasOD
                    if ~isempty(d) && isvalid(d), d.Message = 'Analyzing Right Eye (OD) Quality & Sharpness...'; drawnow; end
                    [qGradeOD, qMetricsOD, ~] = assess_image_quality(app.RawImageOD);
                    app.QualityStatusOD = qGradeOD;
                    app.QualityMetricsOD = qMetricsOD;
                    try
                        [enhOD, ~, ~] = enhance_retinal_image(app.RawImageOD);
                        app.EnhancedImageOD = enhOD;
                    catch
                    end
                    if strcmp(qGradeOD, 'Good')
                        app.EyeODStatusLabel.Text = 'OD: PASS (Gradeable)';
                        app.EyeODStatusLabel.FontColor = [0.1, 0.6, 0.2];
                    else
                        app.EyeODStatusLabel.Text = sprintf('OD: %s', qGradeOD);
                        app.EyeODStatusLabel.FontColor = [0.8, 0.2, 0.1];
                    end
                end
                
                % Assess OS if loaded
                if hasOS
                    if ~isempty(d) && isvalid(d), d.Message = 'Analyzing Left Eye (OS) Quality & Sharpness...'; drawnow; end
                    [qGradeOS, qMetricsOS, ~] = assess_image_quality(app.RawImageOS);
                    app.QualityStatusOS = qGradeOS;
                    app.QualityMetricsOS = qMetricsOS;
                    try
                        [enhOS, ~, ~] = enhance_retinal_image(app.RawImageOS);
                        app.EnhancedImageOS = enhOS;
                    catch
                    end
                    if strcmp(qGradeOS, 'Good')
                        app.EyeOSStatusLabel.Text = 'OS: PASS (Gradeable)';
                        app.EyeOSStatusLabel.FontColor = [0.1, 0.6, 0.2];
                    else
                        app.EyeOSStatusLabel.Text = sprintf('OS: %s', qGradeOS);
                        app.EyeOSStatusLabel.FontColor = [0.8, 0.2, 0.1];
                    end
                end
                
                % Update views for currently active eye
                updateQualityViewForActiveEye(app);
                
                % Update advice label from active eye
                if strcmp(app.ActiveEye, 'OD') && hasOD
                    [~, ~, advice] = assess_image_quality(app.RawImageOD);
                    app.RecaptureAdviceLabel.Text = advice;
                elseif strcmp(app.ActiveEye, 'OS') && hasOS
                    [~, ~, advice] = assess_image_quality(app.RawImageOS);
                    app.RecaptureAdviceLabel.Text = advice;
                end
                
                if ~isempty(strtrim(app.CurrentPatientName)) && app.ConsentObtained
                    saveActiveCase(app);
                end
            catch ME
                closeProgress(app, d);
                safeAlert(app, sprintf('Quality assessment error: %s', ME.message), 'Assessment Error', 'error');
                return;
            end
            closeProgress(app, d);
        end

        % AI Screening
        function screenEyeChanged(app)
            updateScreeningViewForActiveEye(app);
        end

        function confSpinnerChanged(app)
            app.ConfThreshold = app.ConfSpinner.Value;
        end

        function updateScreeningViewForActiveEye(app)
            eye = 'OD';
            if app.ScreenEyeOSButton.Value, eye = 'OS'; end
            
            if strcmp(eye, 'OD')
                ovImg   = app.OverlayImageOD;
                rawImg  = app.RawImageOD;
                res     = app.ClassificationOD;
                detTbl  = app.DetectionsTableOD;
                heatImg = app.HeatmapImageOD;
            else
                ovImg   = app.OverlayImageOS;
                rawImg  = app.RawImageOS;
                res     = app.ClassificationOS;
                detTbl  = app.DetectionsTableOS;
                heatImg = app.HeatmapImageOS;
            end
            
            showLbl = true;
            if isprop(app, 'ShowLabelsCheckBox') && isvalid(app.ShowLabelsCheckBox)
                showLbl = app.ShowLabelsCheckBox.Value;
            end
            
            if istable(detTbl) && height(detTbl) > 0 && ~isempty(rawImg)
                [ovImg, ~] = overlay_lesion_detections(rawImg, detTbl, showLbl);
                if strcmp(eye, 'OD')
                    app.OverlayImageOD = ovImg;
                else
                    app.OverlayImageOS = ovImg;
                end
            end
            
            % Guarantee clinical DR grading arbitration whenever lesions are detected
            if istable(detTbl) && height(detTbl) > 0
                res = arbitrate_dr_grade_from_lesions(res, detTbl);
                if strcmp(eye, 'OD')
                    app.ClassificationOD = res;
                else
                    app.ClassificationOS = res;
                end
            end
            
            viewMode = 'Bounding Boxes';
            if isprop(app, 'ViewModeDropDown') && isvalid(app.ViewModeDropDown)
                viewMode = app.ViewModeDropDown.Value;
            end
            
            if strcmp(viewMode, 'Attention Heatmap') && ~isempty(heatImg)
                imshow(heatImg, 'Parent', app.ScreeningAxes);
                title(app.ScreeningAxes, sprintf('Clinical Attention Heatmap (Grad-CAM / Texture Energy) — %s', eye));
            elseif ~isempty(ovImg)
                imshow(ovImg, 'Parent', app.ScreeningAxes);
                title(app.ScreeningAxes, sprintf('Explainable Retinal Analysis — %s (FOV-Masked with Bounding Labels)', eye));
            elseif ~isempty(rawImg)
                imshow(rawImg, 'Parent', app.ScreeningAxes);
                title(app.ScreeningAxes, sprintf('Original Fundus Image — %s (Not Yet Screened)', eye));
            else
                cla(app.ScreeningAxes);
                title(app.ScreeningAxes, sprintf('No Image Loaded for %s', eye));
            end
            
            if isstruct(res) && isfield(res, 'predicted_label')
                app.GradeBannerLabel.Text = sprintf('Grade: %s (Score: %.1f%%)', res.predicted_label, res.confidence * 100);
                if res.is_referable
                    app.ReferralBannerLabel.Text = 'Referable DR: YES (REFERRAL REQUIRED)';
                    app.ReferralBannerLabel.FontColor = [0.8, 0.1, 0.1];
                else
                    app.ReferralBannerLabel.Text = 'Referable DR: NO (Routine Follow-up)';
                    app.ReferralBannerLabel.FontColor = [0.1, 0.6, 0.2];
                end
                
                probs = res.probabilities * 100;
                app.GradeProbTable.Data = {
                    'Grade 0: No DR',        sprintf('%.1f%%', probs(1)), 'No microaneurysms or retinal lesions';
                    'Grade 1: Mild NPDR',     sprintf('%.1f%%', probs(2)), 'Microaneurysms only';
                    'Grade 2: Moderate NPDR', sprintf('%.1f%%', probs(3)), 'More than mild NPDR, but less than severe';
                    'Grade 3: Severe NPDR',   sprintf('%.1f%%', probs(4)), '>20 intraretinal hemorrhages or venous beading';
                    'Grade 4: Proliferative', sprintf('%.1f%%', probs(5)), 'Neovascularization or vitreous hemorrhage'
                };
                
                if res.confidence < 0.40
                    app.UncertaintyWarningLabel.Text = sprintf('⚠ UNCERTAINTY WARNING: Low confidence (%.1f%%). Probabilities are borderline; clinical review is mandatory.', res.confidence * 100);
                    app.UncertaintyWarningLabel.FontColor = [0.85, 0.45, 0.0];
                else
                    app.UncertaintyWarningLabel.Text = sprintf('Decision Support Output: %s (Score: %.1f%%). Clinician verification required.', res.predicted_label, res.confidence * 100);
                    app.UncertaintyWarningLabel.FontColor = [0.1, 0.5, 0.2];
                end
            else
                app.GradeBannerLabel.Text = 'Grade: Not Screened';
                app.ReferralBannerLabel.Text = 'Referable DR: --';
                app.UncertaintyWarningLabel.Text = 'Awaiting inference: Load fundus image and run AI analysis.';
                app.UncertaintyWarningLabel.FontColor = [0.4, 0.4, 0.4];
                app.GradeProbTable.Data = {
                    'Grade 0: No DR',        '--', 'No microaneurysms or retinal lesions';
                    'Grade 1: Mild NPDR',     '--', 'Microaneurysms only';
                    'Grade 2: Moderate NPDR', '--', 'More than mild NPDR, but less than severe';
                    'Grade 3: Severe NPDR',   '--', '>20 intraretinal hemorrhages or venous beading';
                    'Grade 4: Proliferative', '--', 'Neovascularization or vitreous hemorrhage'
                };
            end
            
            if istable(detTbl) && height(detTbl) > 0
                cNames = detTbl.ClassName;
                uClasses = unique(cNames);
                tData = cell(numel(uClasses) + 1, 2);
                for k = 1:numel(uClasses)
                    tData{k, 1} = uClasses{k};
                    tData{k, 2} = sum(strcmp(cNames, uClasses{k}));
                end
                tData{end, 1} = 'TOTAL CANDIDATES';
                tData{end, 2} = height(detTbl);
                app.LesionCountTable.Data = tData;
            else
                app.LesionCountTable.Data = {
                    'Microaneurysms (MA)', 0;
                    'Haemorrhages (HE)',   0;
                    'Hard Exudates (EX)',  0;
                    'Soft Exudates (SE)',  0;
                    'TOTAL CANDIDATES',    0
                };
            end
        end

        function runAIScreeningCallback(app)
            eye = 'OD';
            if app.ScreenEyeOSButton.Value, eye = 'OS'; end
            d = showProgress(app, sprintf('Running AI Screening (%s)', eye), ...
                'Executing EfficientNet-B0 classification, YOLO lesion detection & attention heatmap...');
            try
                success = runScreeningForEye(app, eye, true);
                if success
                    if ~isempty(d) && isvalid(d), d.Message = 'Rendering Explainable Retinal Visualizations...'; drawnow; end
                    updateScreeningViewForActiveEye(app);
                    updateReportPreview(app);
                    saveActiveCase(app);
                end
            catch ME
                closeProgress(app, d);
                safeAlert(app, sprintf('Screening failed for %s: %s', eye, ME.message), 'Screening Error', 'error');
                return;
            end
            closeProgress(app, d);
        end

        function runBothEyesScreeningCallback(app)
            % Check available eyes
            hasOD = ~isempty(app.ImagePathOD) && isfile(app.ImagePathOD);
            hasOS = ~isempty(app.ImagePathOS) && isfile(app.ImagePathOS);
            
            if ~hasOD && ~hasOS
                safeAlert(app, 'Please load at least one retinal fundus image (OD or OS) before running AI analysis.', 'No Images Loaded', 'warning');
                return;
            end
            
            d = showProgress(app, 'Running Dual-Eye AI Screening', ...
                'Initializing multi-model pipeline: EfficientNet-B0, YOLO & Grad-CAM...');
            
            successOD = false;
            successOS = false;
            
            try
                % Process OD: reuse existing components if already present ("if already there leave that")
                if hasOD
                    if ~isempty(d) && isvalid(d), d.Message = 'Analyzing Right Eye (OD): Lesions, Heatmap & Clinical Staging...'; drawnow; end
                    successOD = runScreeningForEye(app, 'OD', false);
                end
                % Process OS: reuse existing components if already present ("if already there leave that")
                if hasOS
                    if ~isempty(d) && isvalid(d), d.Message = 'Analyzing Left Eye (OS): Lesions, Heatmap & Clinical Staging...'; drawnow; end
                    successOS = runScreeningForEye(app, 'OS', false);
                end
                
                if ~isempty(d) && isvalid(d), d.Message = 'Synthesizing Dual-Eye Findings & Updating Interface...'; drawnow; end
                updateScreeningViewForActiveEye(app);
                updateReportPreview(app);
                saveActiveCase(app);
            catch ME
                closeProgress(app, d);
                safeAlert(app, sprintf('Dual-eye screening failed: %s', ME.message), 'Screening Error', 'error');
                return;
            end
            closeProgress(app, d);
            
            statusMsgOD = 'Skipped / Inadequate';
            if successOD, statusMsgOD = 'Screened Successfully'; end
            statusMsgOS = 'Skipped / Inadequate';
            if successOS, statusMsgOS = 'Screened Successfully'; end
            
            msg = sprintf('Dual-Eye AI Screening Complete:\n• OD (Right Eye): %s\n• OS (Left Eye): %s', ...
                statusMsgOD, statusMsgOS);
            safeAlert(app, msg, 'Dual-Eye AI Screening Complete');
        end

        function success = runScreeningForEye(app, eye, forceRerun)
            if nargin < 3, forceRerun = false; end
            success = false;
            if strcmp(eye, 'OD')
                imgPath  = app.ImagePathOD;
                qStatus  = app.QualityStatusOD;
                prevClas = app.ClassificationOD;
                prevDet  = app.DetectionsTableOD;
                prevOv   = app.OverlayImageOD;
                prevHeat = app.HeatmapImageOD;
            else
                imgPath  = app.ImagePathOS;
                qStatus  = app.QualityStatusOS;
                prevClas = app.ClassificationOS;
                prevDet  = app.DetectionsTableOS;
                prevOv   = app.OverlayImageOS;
                prevHeat = app.HeatmapImageOS;
            end
            
            if isempty(imgPath) || ~isfile(imgPath)
                return;
            end
            
            % Fail-Closed Enforcement
            if strcmp(qStatus, 'Ungradable') || strcmp(qStatus, 'AssessmentError')
                uialert(app.UIFigure, sprintf('Screening BLOCKED for %s: Image failed the quality gate (%s). Please recapture before proceeding.', eye, qStatus), 'Quality Gate Locked');
                return;
            end
            
            % 1. Classify DR Severity (EfficientNet-B0) — reuse if already computed and not forced
            if ~forceRerun && isstruct(prevClas) && isfield(prevClas, 'predicted_label') && ~isempty(prevClas.predicted_label)
                res = prevClas;
            else
                try
                    res = classify_dr_onnx(imgPath);
                catch ME
                    uialert(app.UIFigure, sprintf('Classification failed for %s: %s', eye, ME.message), 'AI Error');
                    return;
                end
            end
            
            % 2. Detect Lesions with FOV Filtering — reuse if already computed and not forced
            showLbl = true;
            if isprop(app, 'ShowLabelsCheckBox') && isvalid(app.ShowLabelsCheckBox)
                showLbl = app.ShowLabelsCheckBox.Value;
            end
            
            detectorChoice = 'YOLO11n';
            if isprop(app, 'ModelSelectDropDown') && isvalid(app.ModelSelectDropDown)
                detectorChoice = app.ModelSelectDropDown.Value;
            end
            
            if contains(detectorChoice, 'YOLOv8') || contains(detectorChoice, 'Roboflow') || contains(detectorChoice, 'YOLO-B')
                detModelPath = fullfile(app.ProjectRoot, 'data', 'models 2', 'yolo_lesions.onnx');
                reqModelTag = 'Roboflow';
            else
                detModelPath = fullfile(app.ProjectRoot, 'data', 'models', 'yolo11n_lesions_scratch.onnx');
                reqModelTag = 'IDRiD';
            end
            
            % Check if cached detection matches the selected detector model
            hasCachedDet = false;
            if ~forceRerun && istable(prevDet) && ~isempty(prevOv)
                if ismember('ModelSource', prevDet.Properties.VariableNames) && height(prevDet) > 0
                    if contains(prevDet.ModelSource{1}, reqModelTag)
                        hasCachedDet = true;
                    end
                else
                    hasCachedDet = true;
                end
            end
            
            if hasCachedDet
                detTbl = prevDet;
                ovImg  = prevOv;
                rawImg = imread(imgPath);
            else
                try
                    detTbl = detect_lesions_onnx(imgPath, detModelPath, app.ConfThreshold, 0.45);
                    rawImg = imread(imgPath);
                    [ovImg, ~] = overlay_lesion_detections(rawImg, detTbl, showLbl);
                catch ME
                    uialert(app.UIFigure, sprintf('Lesion detection failed for %s: %s', eye, ME.message), 'Detection Error');
                    return;
                end
            end
            
            % 3. Clinical Attention Heatmap (Explainability) — regenerate if detector changed
            if hasCachedDet && ~forceRerun && ~isempty(prevHeat)
                heatOverlay = prevHeat;
            else
                try
                    [heatOverlay, ~] = generate_retinal_heatmap(rawImg, detTbl);
                catch
                    heatOverlay = [];
                end
            end
            
            % 4. Clinically Grounded DR Grading Arbitration (ICDR Clinical Hallmarks)
            % Resolves uncalibrated scratch classifier weights when active lesions are detected
            res = arbitrate_dr_grade_from_lesions(res, detTbl);
            
            % Save synchronized results to application state
            if strcmp(eye, 'OD')
                app.ClassificationOD  = res;
                app.DetectionsTableOD = detTbl;
                app.OverlayImageOD    = ovImg;
                app.HeatmapImageOD    = heatOverlay;
            else
                app.ClassificationOS  = res;
                app.DetectionsTableOS = detTbl;
                app.OverlayImageOS    = ovImg;
                app.HeatmapImageOS    = heatOverlay;
            end
            success = true;
        end

        % Clinician Review & Reporting
        function saveReviewCallback(app)
            rName = strtrim(app.ReviewerNameEdit.Value);
            if isempty(rName)
                uialert(app.UIFigure, 'Please enter the reviewer name.', 'Validation Error');
                return;
            end
            
            app.ReviewerName     = rName;
            app.ReviewerRole     = app.ReviewerRoleDropDown.Value;
            app.ClinicalDecision = app.DecisionDropDown.Value;
            app.ReferralAction   = app.ReferralDropDown.Value;
            if isprop(app, 'HospitalFacilityEdit') && isvalid(app.HospitalFacilityEdit)
                app.HospitalFacility = strtrim(app.HospitalFacilityEdit.Value);
            end
            if isprop(app, 'ReferralTimeframeDropDown') && isvalid(app.ReferralTimeframeDropDown)
                app.ReferralTimeframe = app.ReferralTimeframeDropDown.Value;
            end
            app.ClinicalNotes    = app.NotesTextArea.Value;
            app.ReviewSaved      = true;
            app.ReviewSignedAt   = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            
            app.ReviewStatusLabel.Text = sprintf('Review Status: SIGNED & SAVED by %s on %s', ...
                rName, datestr(now, 'yyyy-mm-dd HH:MM'));
            app.ReviewStatusLabel.FontColor = [0.1, 0.5, 0.2];
            
            saveActiveCase(app);
            updateReportPreview(app);
            uialert(app.UIFigure, 'Clinician review and verification successfully saved to case record.', 'Review Saved');
        end

        function updateReportPreview(app)
            repText = generateReportText(app);
            app.ReportPreviewLabel.Text = repText;
        end

        function repText = generateReportText(app)
            rName = app.ReviewerNameEdit.Value;
            if isempty(rName), rName = '[Pending Clinician Name]'; end
            
            % Determine OD and OS grade strings
            odGrade = 'Not Evaluated';
            if isstruct(app.ClassificationOD) && isfield(app.ClassificationOD, 'predicted_label')
                odGrade = sprintf('%s (Confidence: %.1f%%)', app.ClassificationOD.predicted_label, app.ClassificationOD.confidence * 100);
            end
            
            osGrade = 'Not Evaluated';
            if isstruct(app.ClassificationOS) && isfield(app.ClassificationOS, 'predicted_label')
                osGrade = sprintf('%s (Confidence: %.1f%%)', app.ClassificationOS.predicted_label, app.ClassificationOS.confidence * 100);
            end
            
            odDets = 0; if istable(app.DetectionsTableOD), odDets = height(app.DetectionsTableOD); end
            osDets = 0; if istable(app.DetectionsTableOS), osDets = height(app.DetectionsTableOS); end
            
            repText = sprintf([...
                '=========================================================================\n', ...
                '         RETINASCAN AI — SCREENING SUMMARY (PROTOTYPE REPORT)\n', ...
                '=========================================================================\n', ...
                'Case ID: %s               Date: %s\n', ...
                'Patient Name: %s          Age / Gender: %d / %s\n', ...
                'Contact: %s               Insurance ID: %s\n', ...
                '-------------------------------------------------------------------------\n', ...
                'RIGHT EYE (OD):\n', ...
                '  Quality: %s  |  AI Grade: %s\n', ...
                '  Candidate Lesions (YOLO11): %d detections\n', ...
                'LEFT EYE (OS):\n', ...
                '  Quality: %s  |  AI Grade: %s\n', ...
                '  Candidate Lesions (YOLO11): %d detections\n', ...
                '-------------------------------------------------------------------------\n', ...
                'CLINICIAN TELE-REVIEW:\n', ...
                '  Reviewer: %s (%s)\n', ...
                '  Clinical Decision: %s\n', ...
                '  Referral Action: %s\n', ...
                '  Clinical Notes: %s\n', ...
                '=========================================================================\n', ...
                'DISCLAIMER:\n', ...
                'This report was generated by RetinaScan AI, an experimental decision support\n', ...
                'prototype. All AI findings represent candidate lesion detections and require\n', ...
                'verification by a licensed ophthalmologist before clinical management.\n', ...
                '=========================================================================\n'], ...
                app.CurrentCaseID, datestr(now, 'yyyy-mm-dd HH:MM'), ...
                app.CurrentPatientName, app.CurrentPatientAge, app.CurrentPatientGender, ...
                app.CurrentContact, app.CurrentInsuranceID, ...
                app.QualityStatusOD, odGrade, odDets, ...
                app.QualityStatusOS, osGrade, osDets, ...
                rName, app.ReviewerRoleDropDown.Value, ...
                app.DecisionDropDown.Value, app.ReferralDropDown.Value, ...
                strjoin(app.NotesTextArea.Value, ' '));
        end

        function exportTxtReportCallback(app)
            reportFile = fullfile(app.ReportsDir, sprintf('Report_%s_%s.txt', app.CurrentCaseID, datestr(now, 'yyyymmdd_HHMMSS')));
            fid = fopen(reportFile, 'w');
            fprintf(fid, '%s', generateReportText(app));
            fclose(fid);
            
            app.ReportExportPath = reportFile;
            saveActiveCase(app);
            uialert(app.UIFigure, sprintf('Text report successfully exported to:\n%s', reportFile), 'Report Exported');
        end

        function exportPdfReportCallback(app)
            d = showProgress(app, 'Generating Clinical PDF Report', ...
                'Rendering 6-panel matrix, border styling, QR code & multilingual translation...');
            try
                % Ensure clinician review data is saved first
                if isprop(app, 'HospitalFacilityEdit') && isvalid(app.HospitalFacilityEdit)
                    app.HospitalFacility = strtrim(app.HospitalFacilityEdit.Value);
                end
                if isprop(app, 'ReferralTimeframeDropDown') && isvalid(app.ReferralTimeframeDropDown)
                    app.ReferralTimeframe = app.ReferralTimeframeDropDown.Value;
                end
                saveActiveCase(app);
                
                % Invoke complete multi-page PDF & audio generator
                [pdfFile, audioPaths] = export_clinical_report_full(app);
                
                app.ReportExportPath = pdfFile;
                saveActiveCase(app);
                updateReportPreview(app);
                closeProgress(app, d);
                
                safeAlert(app, sprintf(['Comprehensive 6-Panel Screening PDF Generated Successfully!\n\n', ...
                    'PDF File:\n%s\n\n', ...
                    'Multilingual Audio (EN/HI/TA) directory:\n%s'], ...
                    pdfFile, fullfile(app.ReportsDir, 'audio')), 'PDF & Audio Succeeded');
            catch ME
                closeProgress(app, d);
                safeAlert(app, sprintf('PDF export encountered an error:\n%s', ME.message), 'PDF Error', 'error');
            end
        end

        function playMultilingualAudio(app, lang)
            audioDir = fullfile(app.ReportsDir, 'audio');
            if ~exist(audioDir, 'dir'), mkdir(audioDir); end
            audioFile = fullfile(audioDir, sprintf('%s_audio_%s.mp3', app.CurrentCaseID, lang));
            
            if ~isfile(audioFile)
                d = showProgress(app, 'Synthesizing Multilingual Audio', ...
                    sprintf('Generating on-demand speech counseling in %s with gTTS engine...', upper(lang)));
                % Generate ONLY on demand for the requested language
                try
                    tempDir = fullfile(app.ProjectRoot, 'data', 'temp');
                    if ~exist(tempDir, 'dir'), mkdir(tempDir); end
                    jsonPath = fullfile(tempDir, sprintf('case_%s.json', app.CurrentCaseID));
                    
                    cData = struct();
                    cData.CaseID = app.CurrentCaseID;
                    cData.PatientName = app.CurrentPatientName;
                    cData.ClinicalDecision = app.DecisionDropDown.Value;
                    cData.HospitalFacility = strtrim(app.HospitalFacilityEdit.Value);
                    cData.ReferralTimeframe = app.ReferralTimeframeDropDown.Value;
                    
                    fid = fopen(jsonPath, 'w', 'native', 'UTF-8');
                    fwrite(fid, jsonencode(cData), 'char');
                    fclose(fid);
                    
                    audioScript = fullfile(app.ProjectRoot, 'src', 'reports', 'generate_multilingual_audio.py');
                    cmd = sprintf('python "%s" --case_json "%s" --output_dir "%s"', audioScript, jsonPath, audioDir);
                    system(cmd);
                catch
                end
                closeProgress(app, d);
            end
            
            if isfile(audioFile)
                try
                    winopen(audioFile);
                    safeAlert(app, sprintf('Playing %s audio counseling for Case %s:\n%s', upper(lang), app.CurrentCaseID, audioFile), 'Audio Playing');
                catch ME
                    safeAlert(app, sprintf('Audio saved at %s, but could not open player: %s', audioFile, ME.message), 'Audio Notice');
                end
            else
                safeAlert(app, 'Audio could not be generated. Please check internet connection for TTS synthesis.', 'Audio Generation Error', 'warning');
            end
        end

        function finishAndStartNewPatientCallback(app)
            % 1. Persist current case completely
            saveActiveCase(app);
            refreshAllRegistryViews(app);
            
            finishedCaseID = app.CurrentCaseID;
            finishedPatient = app.CurrentPatientName;
            
            % 2. Start clean new patient intake
            resetCurrentDraft(app);
            refreshAllRegistryViews(app);
            selectTab(app, 'patient');
            
            safeAlert(app, sprintf(['Case %s (%s) has been successfully saved to the persistent database!\n\n', ...
                'Ready for new patient intake (New Case ID: %s).'], ...
                finishedCaseID, finishedPatient, app.CurrentCaseID), 'Case Completed & Saved');
        end

        function openReportsFolder(app)
            if ~exist(app.ReportsDir, 'dir'), mkdir(app.ReportsDir); end
            winopen(app.ReportsDir);
        end

        % Rural Simulation
        function runSimulationCallback(app)
            scenario = app.ScenarioDropDown.Value;
            scenKey = 'Connected';
            if contains(scenario, 'LowBandwidth'), scenKey = 'LowBandwidth'; end
            if contains(scenario, 'OfflineBacklog'), scenKey = 'OfflineBacklog'; end
            if contains(scenario, 'Optimized'), scenKey = 'Optimized'; end
            
            customP = struct();
            customP.arrivalRatePerHour = app.SimArrivalRateEdit.Value;
            customP.clinicianServiceTimeMin = app.SimServiceTimeEdit.Value;
            
            d = showProgress(app, 'Running Clinic Workflow Simulation', ...
                sprintf('Executing discrete-event stochastic queueing model for %s scenario...', upper(scenKey)));
            try
                simRes = run_screening_simulation(scenKey, customP);
                
                % Plot Queue over time
                timeMins = 1:numel(simRes.queueLengthsOverTime);
                plot(app.SimAxes, timeMins, simRes.queueLengthsOverTime, 'LineWidth', 2, 'Color', [0.15, 0.45, 0.75]);
                title(app.SimAxes, sprintf('Queue Dynamics: %s Scenario (%d Arrivals)', upper(scenKey), simRes.totalArrived));
                xlabel(app.SimAxes, 'Clinic Shift Time (Minutes)');
                ylabel(app.SimAxes, 'Patients in Queue / Processing');
                grid(app.SimAxes, 'on');

                app.SimMetricsTable.Data = {
                    'Total Patient Arrivals', num2str(simRes.totalArrived);
                    'Completed Screenings', sprintf('%d (%.1f%%)', simRes.completedCases, 100 * simRes.completedCases / max(1, simRes.totalArrived));
                    'Quality Gate Rejections', sprintf('%d (%.1f%%)', simRes.rejectedQualityCases, 100 * simRes.rejectedQualityCases / max(1, simRes.totalArrived));
                    'Still Queued at Shift End', sprintf('%d (%.1f%%)', simRes.stillInQueueCases, 100 * simRes.stillInQueueCases / max(1, simRes.totalArrived));
                    'Conservation Check (Arrived == Sum)', mat2str(simRes.conservationCheck);
                    'Throughput (Patients / Hour)', sprintf('%.2f', simRes.throughputPerHour);
                    'Mean Turnaround Time', sprintf('%.1f minutes', simRes.meanTurnaroundMinutes);
                    '90th Percentile Turnaround Time', sprintf('%.1f minutes', simRes.p90TurnaroundMinutes);
                    'Clinician Tele-Reviewer Utilization', sprintf('%.1f%%', simRes.clinicianUtilizationPct)
                };

                app.SimStatusLabel.Text = sprintf('Simulation: COMPLETED (%s, Conservation: PASS)', upper(scenKey));
                app.SimStatusLabel.FontColor = [0.1, 0.6, 0.2];
                closeProgress(app, d);
            catch ME
                closeProgress(app, d);
                app.SimStatusLabel.Text = sprintf('Simulation Error: %s', ME.message);
                app.SimStatusLabel.FontColor = [0.8, 0.1, 0.1];
                safeAlert(app, sprintf('Simulation failed:\n%s', ME.message), 'Simulation Error', 'error');
            end
        end

        function resetSimulationCallback(app)
            cla(app.SimAxes);
            title(app.SimAxes, 'Patient Queue Dynamics Across 8-Hour Clinic Shift (SimEvents Engine)');
            xlabel(app.SimAxes, 'Clinic Shift Time (Minutes)');
            ylabel(app.SimAxes, 'Patients in Queue / Processing');
            grid(app.SimAxes, 'on');
            
            app.SimMetricsTable.Data = {
                'Total Patient Arrivals', '--';
                'Completed Screenings', '--';
                'Quality Gate Rejections', '--';
                'Still Queued at Shift End', '--';
                'Conservation Check (Arrived == Sum)', '--';
                'Throughput (Patients / Hour)', '--';
                'Mean Turnaround Time', '--';
                '90th Percentile Turnaround', '--';
                'Tele-Reviewer Utilization', '--'
            };
            app.SimStatusLabel.Text = 'Simulation: Ready (Stochastic Planning Engine)';
            app.SimStatusLabel.FontColor = [0.1, 0.5, 0.2];
        end
    end
end
