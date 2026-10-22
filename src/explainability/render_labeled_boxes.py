"""
RetinaScan AI — High-Visibility Bounding Box & Lesion Label Renderer
Uses OpenCV to guarantee high-contrast, crystal-clear bounding badges with lesion abbreviations
and confidence scores on any resolution fundus photograph.
"""

import os
import sys
import json
import argparse
import cv2
import numpy as np

def render_lesion_overlays(img_path, dets_json, out_path, show_labels=True):
    img = cv2.imread(img_path)
    if img is None:
        raise ValueError(f"Could not load image from {img_path}")
        
    H, W = img.shape[:2]
    
    with open(dets_json, 'r', encoding='utf-8') as f:
        dets = json.load(f)
        
    line_thick = max(1, int(min(H, W) / 500))
    font_scale = max(0.35, min(H, W) / 1600.0)
    font_thick = 1
    
    colors = {
        'microaneurysm': (59, 235, 255),    # Yellow (BGR)
        'haemorrhage': (54, 67, 244),      # Red
        'hemorrhage': (54, 67, 244),
        'hard exudate': (80, 175, 76),     # Green
        'soft exudate': (212, 188, 0),     # Cyan / Light Blue
        'bleeding': (40, 40, 198),         # Crimson
        'scarring': (176, 39, 156)         # Purple
    }
    
    for d in dets:
        cname = d.get('ClassName', 'Lesion')
        conf = float(d.get('Confidence', 0.5))
        x1 = max(1, int(round(d.get('X1', 0))))
        y1 = max(1, int(round(d.get('Y1', 0))))
        x2 = min(W - 1, int(round(d.get('X2', 0))))
        y2 = min(H - 1, int(round(d.get('Y2', 0))))
        
        # Color & tag matching
        col = (212, 188, 0)
        full_tag = 'Soft Exudate'
        low = cname.lower()
        if 'microaneurysm' in low and 'hemorrhage' not in low:
            col = (59, 235, 255)
            full_tag = 'Microaneurysm'
        elif 'haemorrhage' in low or ('hemorrhage' in low and 'microaneurysm' not in low):
            col = (54, 67, 244)
            full_tag = 'Haemorrhage'
        elif 'hard exudate' in low:
            col = (80, 175, 76)
            full_tag = 'Hard Exudate'
        elif 'soft exudate' in low or 'cotton' in low:
            col = (212, 188, 0)
            full_tag = 'Soft Exudate'
        elif 'microaneurysms hemorrhages' in low:
            col = (0, 152, 255)
            full_tag = 'MA / Hemorrhage'
        elif 'bleeding' in low:
            col = (40, 40, 198)
            full_tag = 'Bleeding'
        elif 'scarring' in low:
            col = (176, 39, 156)
            full_tag = 'Retinal Scarring'
        else:
            col = (212, 188, 0)
            full_tag = cname
        
        # Draw bounding rectangle
        cv2.rectangle(img, (x1, y1), (x2, y2), col, line_thick)
        
        if show_labels:
            lbl = f"{full_tag} {conf:.2f}"
            (tw, th), baseline = cv2.getTextSize(lbl, cv2.FONT_HERSHEY_SIMPLEX, font_scale, font_thick)
            by1 = max(1, y1 - th - 6)
            by2 = y1
            bx2 = min(W - 1, x1 + tw + 6)
            
            # Draw solid high-contrast background badge
            cv2.rectangle(img, (x1, by1), (bx2, by2), col, -1)
            # Outline badge
            cv2.rectangle(img, (x1, by1), (bx2, by2), (0, 0, 0), 1)
            # Text (Dark text on vibrant background)
            cv2.putText(img, lbl, (x1 + 3, y1 - 3), cv2.FONT_HERSHEY_SIMPLEX, font_scale, (0, 0, 0), font_thick, cv2.LINE_AA)
            
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    cv2.imwrite(out_path, img)
    return out_path

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--image_path', required=True)
    parser.add_argument('--dets_json', required=True)
    parser.add_argument('--output_path', required=True)
    parser.add_argument('--show_labels', default='true')
    args = parser.parse_args()
    
    show_lbl = args.show_labels.lower() in ('true', '1', 'yes')
    res = render_lesion_overlays(args.image_path, args.dets_json, args.output_path, show_lbl)
    print("SUCCESS:", res)
