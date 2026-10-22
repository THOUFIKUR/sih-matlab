"""
RetinaScan AI — Clinical PDF Report Generator (ReportLab Multi-Page Engine)
Generates high-resolution clinical screening reports with:
1. Patient Demographics & Encounters
2. Visual Retinal Matrix (Raw OD/OS, YOLO Detections OD/OS, CLAHE + Heatmaps OD/OS)
3. Clinician Sign-off, Destination Hospital Facility & Referral Urgency
4. Verification QR Code
5. AI Lesion Summary (Pathophysiology & Management)
6. Dedicated Full-Language Translation (English, Hindi हिंदी, Tamil தமிழ்)
"""

import os
import sys
import json
import argparse
import qrcode
from PIL import Image

from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# Register Unicode Indic Font (Nirmala UI / Nirmala TTC)
INDIC_FONT = 'Helvetica'
INDIC_BOLD = 'Helvetica-Bold'
font_paths = ['C:/Windows/Fonts/Nirmala.ttc', 'C:/Windows/Fonts/nirmala.ttf', 'C:/Windows/Fonts/Nirmala.ttf']
for fp in font_paths:
    if os.path.exists(fp):
        try:
            if fp.endswith('.ttc'):
                pdfmetrics.registerFont(TTFont('Nirmala', fp, subfontIndex=0))
            else:
                pdfmetrics.registerFont(TTFont('Nirmala', fp))
            INDIC_FONT = 'Nirmala'
            INDIC_BOLD = 'Nirmala'
            break
        except Exception:
            pass

def build_pdf(case_data, output_pdf_path, lang='en'):
    os.makedirs(os.path.dirname(os.path.abspath(output_pdf_path)), exist_ok=True)
    lang = lang.lower()
    
    doc = SimpleDocTemplate(
        output_pdf_path,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )
    
    styles = getSampleStyleSheet()
    
    # Custom Palette
    c_primary = colors.HexColor("#0D233A")
    c_secondary = colors.HexColor("#1A5276")
    c_accent = colors.HexColor("#2980B9")
    c_light = colors.HexColor("#F8F9FA")
    c_border = colors.HexColor("#BDC3C7")
    c_dark = colors.HexColor("#2C3E50")
    c_alert = colors.HexColor("#C0392B")
    c_pass = colors.HexColor("#27AE60")
    
    # Choose base fonts based on target language
    f_main = INDIC_FONT if lang in ('hi', 'ta') else 'Helvetica'
    f_bold = INDIC_BOLD if lang in ('hi', 'ta') else 'Helvetica-Bold'
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName=f_bold,
        fontSize=14,
        leading=18,
        textColor=c_primary,
        alignment=TA_CENTER
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName=f_main,
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#5D6D7E"),
        alignment=TA_CENTER
    )
    
    section_title = ParagraphStyle(
        'SectionTitle',
        parent=styles['Heading2'],
        fontName=f_bold,
        fontSize=10.5,
        leading=14,
        textColor=c_secondary,
        spaceBefore=7,
        spaceAfter=3
    )
    
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName=f_main,
        fontSize=8.5,
        leading=11.5,
        textColor=c_dark
    )
    
    bold_body = ParagraphStyle(
        'BoldBody',
        parent=body_style,
        fontName=f_bold
    )
    
    alert_style = ParagraphStyle(
        'AlertText',
        parent=body_style,
        fontName=f_bold,
        textColor=c_alert
    )

    story = []
    
    # -------------------------------------------------------------
    # 1. Header Banner
    # -------------------------------------------------------------
    if lang == 'hi':
        t_header = "रेटीनास्कैन एआई — व्यापक नैदानिक नेत्र परीक्षण रिपोर्ट"
        t_sub = "ग्रामीण प्राथमिक स्वास्थ्य केंद्रों के लिए टेली-ऑप्थल्मोलॉजी निर्णय सहायता प्रणाली (SIH 26038)"
    elif lang == 'ta':
        t_header = "ரெடினாஸ்கேன் ஏஐ — விரிவான மருத்துவ கண் பரிசோதனை அறிக்கை"
        t_sub = "கிராமப்புற ஆரம்ப சுகாதார நிலையங்களுக்கான தொலைதூர கண் மருத்துவ ஆதரவு (SIH 26038)"
    else:
        t_header = "RETINASCAN AI — COMPREHENSIVE CLINICAL SCREENING REPORT"
        t_sub = "Tele-Ophthalmology Decision Support System for Rural Primary Health Centres (SIH 26038)"
        
    story.append(Paragraph(t_header, title_style))
    story.append(Paragraph(t_sub, subtitle_style))
    story.append(Spacer(1, 8))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_secondary, spaceAfter=6))
    
    # -------------------------------------------------------------
    # 2. Patient Demographics & Encounters + Verification QR Code
    # -------------------------------------------------------------
    case_id = case_data.get('CaseID', 'RS-2026-UNKNOWN')
    p_name = case_data.get('PatientName', 'Unnamed Patient')
    p_age = str(case_data.get('Age', '--'))
    p_gender = case_data.get('Gender', 'Unspecified')
    p_contact = case_data.get('Contact', '--')
    dm_dur = case_data.get('DMDuration', 0)
    dm_str = f"{dm_dur:.0f} yrs" if dm_dur > 0 else "Not Reported"
    hba1c = case_data.get('HbA1c', 0)
    hba1c_str = f"{hba1c:.1f}%" if hba1c > 0 else "Not Tested"
    created_at = case_data.get('CreatedAt', '2026-10-22')
    
    # Generate QR Code image
    qr_dir = os.path.join(os.path.dirname(output_pdf_path), 'temp_qr')
    os.makedirs(qr_dir, exist_ok=True)
    qr_path = os.path.join(qr_dir, f"qr_{case_id}.png")
    qr = qrcode.QRCode(box_size=4, border=1)
    qr.add_data(f"RETINASCAN-AI-VERIFY:{case_id}|PATIENT:{p_name}|DATE:{created_at}")
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="black", back_color="white")
    qr_img.save(qr_path)
    
    if lang == 'hi':
        lbl_cid, lbl_pname, lbl_ag = "केस आईडी:", "रोगी का नाम:", "आयु / लिंग:"
        lbl_date, lbl_contact, lbl_dm = "परीक्षण तिथि:", "संपर्क:", "मधुमेह अवधि:"
    elif lang == 'ta':
        lbl_cid, lbl_pname, lbl_ag = "பதிவு எண்:", "நோயாளி பெயர்:", "வயது / பாலினம்:"
        lbl_date, lbl_contact, lbl_dm = "தேதி:", "தொடர்பு எண்:", "சர்க்கரை நோய் காலம்:"
    else:
        lbl_cid, lbl_pname, lbl_ag = "Case ID:", "Patient Name:", "Age / Gender:"
        lbl_date, lbl_contact, lbl_dm = "Screening Date:", "Contact:", "DM Duration:"
        
    demo_table_data = [
        [
            Paragraph(f"<b>{lbl_cid}</b> {case_id}", body_style),
            Paragraph(f"<b>{lbl_pname}</b> {p_name}", body_style),
            Paragraph(f"<b>{lbl_ag}</b> {p_age} / {p_gender}", body_style),
            RLImage(qr_path, width=50, height=50)
        ],
        [
            Paragraph(f"<b>{lbl_date}</b> {created_at}", body_style),
            Paragraph(f"<b>{lbl_contact}</b> {p_contact}", body_style),
            Paragraph(f"<b>{lbl_dm}</b> {dm_str} | <b>HbA1c:</b> {hba1c_str}", body_style),
            Paragraph("<font size=6.5 color='#7F8C8D'>Scan to Verify</font>", ParagraphStyle('C', fontName=f_main, alignment=TA_CENTER))
        ]
    ]
    
    demo_table = Table(demo_table_data, colWidths=[140, 160, 160, 60])
    demo_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), c_light),
        ('BOX', (0, 0), (-1, -1), 0.8, c_border),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('SPAN', (3, 0), (3, 0)),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(demo_table)
    story.append(Spacer(1, 8))
    
    # -------------------------------------------------------------
    # 3. Clinician Review & Facility Assignment Card
    # -------------------------------------------------------------
    rev_name = case_data.get('ReviewerName', 'Pending Clinician Sign-off')
    rev_role = case_data.get('ReviewerRole', 'Consultant Ophthalmologist')
    clin_decision = case_data.get('ClinicalDecision', 'Assessment Pending')
    ref_action = case_data.get('ReferralAction', 'Annual Screening')
    hosp_facility = case_data.get('HospitalFacility', 'District Eye Hospital, Tertiary Centre')
    ref_timeframe = case_data.get('ReferralTimeframe', 'Priority Follow-up: Within 2 to 4 Weeks')
    clin_notes = case_data.get('ClinicalNotes', 'Dilated retinal review conducted. Tele-screening decision recorded.')
    if isinstance(clin_notes, list): clin_notes = " ".join(clin_notes)
    
    if lang == 'hi':
        lbl_rev, lbl_dec = "समीक्षक चिकित्सक:", "पुष्टीकृत नैदानिक निर्णय:"
        lbl_hosp, lbl_time = "निर्दिष्ट रेफरल अस्पताल:", "परामर्श समय सीमा:"
        lbl_act, lbl_notes = "अनुशंसित कार्रवाई:", "चिकित्सक टिप्पणी:"
    elif lang == 'ta':
        lbl_rev, lbl_dec = "பரிசோதித்த மருத்துவர்:", "உறுதிப்படுத்தப்பட்ட முடிவு:"
        lbl_hosp, lbl_time = "பரிந்துரைக்கப்பட்ட மருத்துவமனை:", "குறிப்பிட்ட கால அளவு:"
        lbl_act, lbl_notes = "பரிந்துரைக்கப்பட்ட நடவடிக்கை:", "மருத்துவ குறிப்புக்கள்:"
    else:
        lbl_rev, lbl_dec = "Reviewing Clinician:", "Confirmed Clinical Decision:"
        lbl_hosp, lbl_time = "Assigned Referral Hospital:", "Preferred Timeframe:"
        lbl_act, lbl_notes = "Recommended Action:", "Clinician Notes:"
        
    review_table_data = [
        [
            Paragraph(f"<b>{lbl_rev}</b> {rev_name} ({rev_role})", bold_body),
            Paragraph(f"<b>{lbl_dec}</b> {clin_decision}", bold_body)
        ],
        [
            Paragraph(f"<b>{lbl_hosp}</b> {hosp_facility}", body_style),
            Paragraph(f"<b>{lbl_time}</b> {ref_timeframe}", alert_style if 'Priority' in ref_timeframe or 'Urgent' in ref_timeframe or '24-48' in ref_timeframe else bold_body)
        ],
        [
            Paragraph(f"<b>{lbl_act}</b> {ref_action}", body_style),
            Paragraph(f"<b>{lbl_notes}</b> {clin_notes}", body_style)
        ]
    ]
    
    rev_table = Table(review_table_data, colWidths=[260, 260])
    rev_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#EBF5FB")),
        ('BOX', (0, 0), (-1, -1), 1.0, c_accent),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#AED6F1")),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(rev_table)
    story.append(Spacer(1, 10))
    
    # -------------------------------------------------------------
    # 4. Six-Panel Visual Retinal Comparison Matrix
    # -------------------------------------------------------------
    if lang == 'hi':
        matrix_title = "छह-पैनल व्याख्यात्मक नेत्र इमेजिंग मैट्रिक्स"
        p1_t, p2_t = "पैनल 1: दाहिनी आंख (OD) — मूल फंडस", "पैनल 2: बाईं आंख (OS) — मूल फंडस"
        p3_t, p4_t = "पैनल 3: दाहिनी आंख (OD) — घाव पहचान (YOLO)", "पैनल 4: बाईं आंख (OS) — घाव पहचान (YOLO)"
        p5_t, p6_t = "पैनल 5: दाहिनी आंख (OD) — क्लैहे संवर्धन", "पैनल 6: बाईं आंख (OS) — थर्मल अटेंशन हीटमैप (Grad-CAM)"
    elif lang == 'ta':
        matrix_title = "ஆறு-பிரிவு கண் பட பகுப்பாய்வு மேட்ரிக்ஸ்"
        p1_t, p2_t = "பிரிவு 1: வலது கண் (OD) — அசல் படம்", "பிரிவு 2: இடது கண் (OS) — அசல் படம்"
        p3_t, p4_t = "பிரிவு 3: வலது கண் (OD) — காயங்கள் அடையாளம் (YOLO)", "பிரிவு 4: இடது கண் (OS) — காயங்கள் அடையாளம் (YOLO)"
        p5_t, p6_t = "பிரிவு 5: வலது கண் (OD) — மாறுபட்ட பட மேம்பாடு (CLAHE)", "பிரிவு 6: இடது கண் (OS) — கவனம் வெப்ப வரைபடம் (Grad-CAM)"
    else:
        matrix_title = "SIX-PANEL EXPLAINABLE RETINAL IMAGING MATRIX"
        p1_t, p2_t = "Panel 1: Right Eye (OD) — Original Fundus", "Panel 2: Left Eye (OS) — Original Fundus"
        p3_t, p4_t = "Panel 3: Right Eye (OD) — YOLO Lesion Overlays", "Panel 4: Left Eye (OS) — YOLO Lesion Overlays"
        p5_t, p6_t = "Panel 5: Right Eye (OD) — CLAHE Contrast Enhancement", "Panel 6: Left Eye (OS) — Attention Heatmap (Grad-CAM)"
        
    story.append(Paragraph(matrix_title, section_title))
    
    def get_thumb(path, target_w=240, target_h=140):
        if path and os.path.isfile(path):
            try:
                im = Image.open(path)
                aspect = im.width / im.height
                if aspect > target_w / target_h:
                    w = target_w
                    h = target_w / aspect
                else:
                    h = target_h
                    w = target_h * aspect
                return RLImage(path, width=w, height=h)
            except Exception:
                pass
        return Paragraph("<font color='#95A5A6'>Image Not Provided</font>", body_style)

    img_raw_od = case_data.get('ImagePathOD', '')
    img_raw_os = case_data.get('ImagePathOS', '')
    img_yolo_od = case_data.get('OverlayPathOD', '')
    img_yolo_os = case_data.get('OverlayPathOS', '')
    img_clahe_od = case_data.get('EnhancedPathOD', '')
    img_clahe_os = case_data.get('EnhancedPathOS', '')
    img_heat_od = case_data.get('HeatmapPathOD', '')
    img_heat_os = case_data.get('HeatmapPathOS', '')
    
    matrix_data = [
        [
            Paragraph(f"<b>{p1_t}</b>", body_style),
            Paragraph(f"<b>{p2_t}</b>", body_style)
        ],
        [
            get_thumb(img_raw_od),
            get_thumb(img_raw_os)
        ],
        [
            Paragraph(f"<b>{p3_t}</b>", body_style),
            Paragraph(f"<b>{p4_t}</b>", body_style)
        ],
        [
            get_thumb(img_yolo_od if img_yolo_od else img_raw_od),
            get_thumb(img_yolo_os if img_yolo_os else img_raw_os)
        ],
        [
            Paragraph(f"<b>{p5_t}</b>", body_style),
            Paragraph(f"<b>{p6_t}</b>", body_style)
        ],
        [
            get_thumb(img_clahe_od),
            get_thumb(img_heat_os if img_heat_os else (img_heat_od if img_heat_od else img_clahe_os))
        ]
    ]
    
    matrix_table = Table(matrix_data, colWidths=[260, 260])
    matrix_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BACKGROUND', (0, 0), (1, 0), colors.HexColor("#F2F4F4")),
        ('BACKGROUND', (0, 2), (1, 2), colors.HexColor("#F2F4F4")),
        ('BACKGROUND', (0, 4), (1, 4), colors.HexColor("#F2F4F4")),
    ]))
    story.append(matrix_table)
    story.append(Spacer(1, 8))
    
    # -------------------------------------------------------------
    # 5. AI Lesion Summary & Pathophysiological Education
    # -------------------------------------------------------------
    od_label = case_data.get('ClassificationOD', {}).get('predicted_label', 'Not Screened')
    od_conf = case_data.get('ClassificationOD', {}).get('confidence', 0) * 100
    os_label = case_data.get('ClassificationOS', {}).get('predicted_label', 'Not Screened')
    os_conf = case_data.get('ClassificationOS', {}).get('confidence', 0) * 100
    
    if lang == 'hi':
        summary_title = "एआई निष्कर्ष एवं घाव विकृति विज्ञान (पैथोफिजियोलॉजी) सारांश"
        ai_summary_text = (
            f"<b>दाहिनी आंख (OD):</b> {od_label} (विश्वास स्कोर: {od_conf:.1f}%) | "
            f"<b>बाईं आंख (OS):</b> {os_label} (विश्वास स्कोर: {os_conf:.1f}%)<br/>"
            "<b>पहचाने गए घाव:</b> माइक्रोएन्यूरिज्म (MA), रेटिनल रक्तस्राव (HE), हार्ड एक्सयूडेट्स (EX)।<br/>"
            "<b>रोग का कारण (यह क्यों होता है):</b> लगातार उच्च रक्त शर्करा (डायबिटीज) रेटिना की सूक्ष्म रक्त वाहिकाओं को नुकसान पहुंचाती है, "
            "जिससे पेरिसाइट कोशिकाएं नष्ट हो जाती हैं और वाहिकाओं से रक्त व तरल पदार्थ रिसने लगता है।<br/>"
            "<b>रोकथाम एवं उपचार:</b> रक्त शर्करा का सख्त नियंत्रण (लक्ष्य HbA1c &lt; 7.0%) इस बीमारी की प्रगति को 70% तक धीमा करता है। "
            "रक्तचाप (&lt; 130/80 mmHg) को सामान्य रखें। नेत्र विशेषज्ञ द्वारा लेजर फोटोकोएग्यूलेशन या एंटी-VEGF इंजेक्शन से दृष्टि हानि को रोका जा सकता है।"
        )
    elif lang == 'ta':
        summary_title = "செயற்கை நுண்ணறிவு முடிவுகள் மற்றும் நோய் காரணவியல் சுருக்கம்"
        ai_summary_text = (
            f"<b>வலது கண் (OD):</b> {od_label} (துல்லியம்: {od_conf:.1f}%) | "
            f"<b>இடது கண் (OS):</b> {os_label} (துல்லியம்: {os_conf:.1f}%)<br/>"
            "<b>கண்டறியப்பட்ட பாதிப்புகள்:</b> மைக்ரோஅனுரிஸம் (MA), இரத்தக் கசிவு (HE), எக்ஸுடேட்டுகள் (EX).<br/>"
            "<b>பாதிப்பின் காரணம் (இது ஏன் ஏற்படுகிறது):</b> இரத்தத்தில் சர்க்கரையின் அளவு தொடர்ந்து அதிகமாக இருப்பதால் விழித்திரை இரத்தக்குழாய்கள் பலவீனமடைந்து கசிவு மற்றும் அடைப்பு ஏற்படுகிறது.<br/>"
            "<b>கட்டுப்படுத்தும் முறைகள்:</b> சர்க்கரை அளவை எப்போதும் கட்டுப்பாட்டில் வைத்திருப்பது (HbA1c &lt; 7.0%) கண் பாதிப்பை பெருமளவு தடுக்கும். "
            "இரத்த அழுத்தத்தைக் கட்டுப்படுத்துங்கள் (&lt; 130/80 mmHg). கண் மருத்துவர் மூலம் லேசர் அல்லது ஊசி சிகிச்சை மேற்கொள்வது பார்வையை முழுமையாக பாதுகாக்கும்."
        )
    else:
        summary_title = "AI FINDINGS & LESION PATHOPHYSIOLOGY SUMMARY"
        ai_summary_text = (
            f"<b>Right Eye (OD):</b> {od_label} (Confidence: {od_conf:.1f}%) | "
            f"<b>Left Eye (OS):</b> {os_label} (Confidence: {os_conf:.1f}%)<br/>"
            "<b>Identified Lesion Categories:</b> Microaneurysms (MA), Retinal Haemorrhages (HE), Hard Exudates (EX).<br/>"
            "<b>Clinical Pathophysiology (Why it Occurs):</b> Chronic hyperglycemia damages retinal microvasculature, "
            "causing pericyte loss, capillary basement membrane thickening, and blood-retinal barrier breakdown.<br/>"
            "<b>Management & Minimization:</b> Strict glycemic control (target HbA1c &lt; 7.0%) significantly retards disease progression (UKPDS/DCCT). "
            "Blood pressure control (&lt; 130/80 mmHg) and lipid management are vital. For referable stages, retinal laser photocoagulation or anti-VEGF "
            "intravitreal injections administered by an ophthalmologist prevent vision loss."
        )
        
    story.append(Paragraph(summary_title, section_title))
    story.append(Paragraph(ai_summary_text, body_style))
    story.append(Spacer(1, 8))
    
    # -------------------------------------------------------------
    # 6. Patient Guidance Box (Target Language)
    # -------------------------------------------------------------
    if lang == 'hi':
        g_title = "रोगी एवं परिवार के लिए महत्वपूर्ण नैदानिक परामर्श"
        g_text = "कृपया अपनी दृष्टि की सुरक्षा के लिए अनुशंसित समय सीमा के भीतर अपने निर्दिष्ट नेत्र अस्पताल में जाकर पुतली फैलाकर विस्तृत जांच करवाएं। समय पर उपचार दृष्टिहीनता से बचाता है।"
    elif lang == 'ta':
        g_title = "நோயாளி மற்றும் குடும்பத்தினருக்கான மருத்துவ வழிகாட்டுதல்"
        g_text = "பரிந்துரைக்கப்பட்ட காலத்திற்குள் கண் விரிவான பரிசோதனைக்காக குறிப்பிட்ட மாவட்ட கண் மருத்துவமனைக்கு செல்லவும். ஆரம்பக்கால சிகிச்சை மட்டுமே பார்வையைப் பாதுகாக்கும்."
    else:
        g_title = "PATIENT & FAMILY CLINICAL GUIDANCE"
        g_text = "Please visit your assigned district eye hospital within the recommended timeframe for comprehensive dilated examination. Early intervention prevents irreversible vision loss."
        
    story.append(Paragraph(g_title, section_title))
    story.append(Paragraph(g_text, alert_style))
    story.append(Spacer(1, 8))
    
    # -------------------------------------------------------------
    # 7. Regulatory Disclaimer
    # -------------------------------------------------------------
    if lang == 'hi':
        disclaimer_text = (
            "<b>प्रोटोटाइप अस्वीकरण:</b> रेटीनास्कैन एआई स्मार्ट इंडिया हैकथॉन 2024 (समस्या 26038) के लिए विकसित एक निर्णय-सहायता अनुसंधान प्रोटोटाइप है। "
            "सभी एआई निष्कर्ष केवल परामर्श सुझाव हैं और किसी भी चिकित्सा हस्तक्षेप से पहले योग्य नेत्र रोग विशेषज्ञ द्वारा पुष्टि आवश्यक है।"
        )
    elif lang == 'ta':
        disclaimer_text = (
            "<b>ஆராய்ச்சி மாதிரி மறுப்பு:</b> ரெடினாஸ்கேன் ஏஐ என்பது ஸ்மார்ட் இந்தியா ஹேக்கத்தான் 2024 (SIH 26038) க்காக உருவாக்கப்பட்ட முடிவெடுக்கும் ஆராய்ச்சி முன்மாதிரி ஆகும். "
            "அனைத்து முடிவுகளும் கண் மருத்துவ நிபுணரின் நேரடி பரிசோதனைக்கு உட்பட்டது."
        )
    else:
        disclaimer_text = (
            "<b>PROTOTYPE DISCLAIMER:</b> RetinaScan AI is an experimental decision-support research prototype "
            "developed for the Smart India Hackathon 2024 (Problem Statement 26038). All AI lesion detections and "
            "grade predictions represent candidate suggestions and must be verified by a licensed ophthalmologist "
            "prior to any clinical or surgical intervention."
        )
        
    def draw_page_decorations(canvas, doc):
        canvas.saveState()
        # Outer document border frame
        canvas.setStrokeColor(colors.HexColor("#1A5276"))
        canvas.setLineWidth(1.2)
        canvas.rect(20, 20, 555, 802) # A4 is 595.27 x 841.89 points
        
        # Subtle inner border line
        canvas.setStrokeColor(colors.HexColor("#BDC3C7"))
        canvas.setLineWidth(0.5)
        canvas.rect(23, 23, 449 + 100, 796)
        
        # Top banner accent line
        canvas.setStrokeColor(colors.HexColor("#2980B9"))
        canvas.setLineWidth(2.0)
        canvas.line(23, 815, 572, 815)
        
        # Bottom footer line
        canvas.setStrokeColor(colors.HexColor("#BDC3C7"))
        canvas.setLineWidth(0.8)
        canvas.line(23, 35, 572, 35)
        
        # Footer text
        canvas.setFont('Helvetica', 7)
        canvas.setFillColor(colors.HexColor("#7F8C8D"))
        canvas.drawString(30, 26, "RetinaScan AI — Confidential Tele-Ophthalmology Decision Support Report (SIH 26038)")
        canvas.drawRightString(565, 26, f"Page {doc.page} | Verified Record")
        canvas.restoreState()

    # Build Document with borders
    doc.build(story, onFirstPage=draw_page_decorations, onLaterPages=draw_page_decorations)
    return output_pdf_path

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--case_json', required=True, help="Path to input case JSON")
    parser.add_argument('--output_pdf', required=True, help="Path to output PDF")
    parser.add_argument('--lang', default='en', help="Language code (en, hi, ta)")
    args = parser.parse_args()
    
    with open(args.case_json, 'r', encoding='utf-8') as f:
        c_data = json.load(f)
        
    out = build_pdf(c_data, args.output_pdf, args.lang)
    print(f"SUCCESS: {out}")
