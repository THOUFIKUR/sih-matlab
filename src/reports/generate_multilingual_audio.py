"""
RetinaScan AI — Multilingual Audio Generation Engine (gTTS)
Generates spoken audio summaries in English, Hindi, and Tamil for rural patient guidance.
"""

import os
import sys
import json
import argparse
from gtts import gTTS

def generate_multilingual_audio(case_data, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    
    p_name = case_data.get('PatientName', 'Patient')
    case_id = case_data.get('CaseID', 'RS-Case')
    decision = case_data.get('ClinicalDecision', 'Assessment Pending')
    facility = case_data.get('HospitalFacility', 'District Eye Hospital')
    timeframe = case_data.get('ReferralTimeframe', 'Within 2 to 4 weeks')
    
    # 1. English Script
    text_en = (
        f"RetinaScan screening summary for {p_name}, Case ID {case_id}. "
        f"Clinical assessment: {decision}. "
        f"You are advised to visit {facility} for further evaluation {timeframe}. "
        f"Early care and regular blood sugar control protect your vision."
    )
    
    # 2. Hindi Script
    text_hi = (
        f"रेटीनास्कैन जांच सारांश: मरीज {p_name}, केस संख्या {case_id}। "
        f"नैदानिक निर्णय: {decision}। "
        f"आपको सलाह दी जाती है कि विस्तृत जांच के लिए {facility} में {timeframe} संपर्क करें। "
        f"रक्त शर्करा का नियंत्रण आपकी आंखों की रोशनी को सुरक्षित रखता है।"
    )
    
    # 3. Tamil Script
    text_ta = (
        f"ரெடினாஸ்கேன் கண் பரிசோதனை சுருக்கம்: நோயாளி {p_name}, பதிவு எண் {case_id}. "
        f"மருத்துவ முடிவு: {decision}. "
        f"விரிவான பரிசோதனைக்காக {facility} மருத்துவமனைக்கு {timeframe} செல்லுமாறு அறிவுறுத்தப்படுகிறீர்கள். "
        f"சர்க்கரை அளவைக் கட்டுப்படுத்துவது பார்வையைப் பாதுகாக்கும்."
    )
    
    results = {}
    
    try:
        path_en = os.path.join(output_dir, f"{case_id}_audio_en.mp3")
        gTTS(text=text_en, lang='en', slow=False).save(path_en)
        results['en'] = path_en
    except Exception as e:
        print(f"Error generating EN audio: {e}")
        
    try:
        path_hi = os.path.join(output_dir, f"{case_id}_audio_hi.mp3")
        gTTS(text=text_hi, lang='hi', slow=False).save(path_hi)
        results['hi'] = path_hi
    except Exception as e:
        print(f"Error generating HI audio: {e}")
        
    try:
        path_ta = os.path.join(output_dir, f"{case_id}_audio_ta.mp3")
        gTTS(text=text_ta, lang='ta', slow=False).save(path_ta)
        results['ta'] = path_ta
    except Exception as e:
        print(f"Error generating TA audio: {e}")
        
    return results

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--case_json', required=True, help="Path to input case JSON")
    parser.add_argument('--output_dir', required=True, help="Directory to save MP3 files")
    args = parser.parse_args()
    
    with open(args.case_json, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    res = generate_multilingual_audio(data, args.output_dir)
    print("SUCCESS:", json.dumps(res))
