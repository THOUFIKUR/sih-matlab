"""
RetinaScan ONNX Inference Bridge
Provides high-speed inference for:
1. 5-Class Diabetic Retinopathy Classification (EfficientNet-B0)
2. 4-Class Retinal Lesion Detection (YOLO11n) with Non-Maximum Suppression (NMS)
Outputs clean JSON for direct consumption by MATLAB.
"""

import sys
import os
import json
import argparse
import numpy as np
from PIL import Image
import onnxruntime as ort

def run_classifier(image_path, model_path):
    if not os.path.isfile(image_path):
        return {"status": "error", "message": f"Image file not found: {image_path}"}
    if not os.path.isfile(model_path):
        return {"status": "error", "message": f"Model file not found: {model_path}"}

    sess = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])
    input_name = sess.get_inputs()[0].name
    
    # Load and preprocess image (224x224 RGB, ImageNet normalization)
    img = Image.open(image_path).convert('RGB')
    orig_w, orig_h = img.size
    img_resized = img.resize((224, 224), Image.BILINEAR)
    arr = np.array(img_resized, dtype=np.float32) / 255.0
    
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    norm_arr = (arr - mean) / std
    
    # Shape: [1, 3, 224, 224] (NCHW)
    tensor = np.transpose(norm_arr, (2, 0, 1))[np.newaxis, ...]
    
    outs = sess.run(None, {input_name: tensor})
    logits = outs[0][0]
    
    # Softmax
    exp_logits = np.exp(logits - np.max(logits))
    probs = exp_logits / np.sum(exp_logits)
    
    grades = ['No DR (0)', 'Mild NPDR (1)', 'Moderate NPDR (2)', 'Severe NPDR (3)', 'Proliferative DR (4)']
    pred_idx = int(np.argmax(probs))
    
    # Referable DR: Grade >= 2
    is_referable = bool(pred_idx >= 2)
    
    return {
        "status": "success",
        "predicted_grade": pred_idx,
        "predicted_label": grades[pred_idx],
        "confidence": float(probs[pred_idx]),
        "probabilities": [float(p) for p in probs],
        "raw_predicted_grade": pred_idx,
        "raw_confidence": float(probs[pred_idx]),
        "raw_probabilities": [float(p) for p in probs],
        "model_name": os.path.basename(model_path),
        "is_referable": is_referable,
        "original_dimensions": [orig_w, orig_h]
    }

def nms(boxes, scores, iou_threshold=0.45):
    if len(boxes) == 0:
        return []
    x1 = boxes[:, 0]
    y1 = boxes[:, 1]
    x2 = boxes[:, 2]
    y2 = boxes[:, 3]
    areas = (x2 - x1) * (y2 - y1)
    order = scores.argsort()[::-1]
    keep = []
    while order.size > 0:
        i = order[0]
        keep.append(i)
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        w = np.maximum(0.0, xx2 - xx1)
        h = np.maximum(0.0, yy2 - yy1)
        inter = w * h
        ovr = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)
        inds = np.where(ovr <= iou_threshold)[0]
        order = order[inds + 1]
    return keep

def run_detector(image_path, model_path, conf_thresh=0.25, iou_thresh=0.45):
    if not os.path.isfile(image_path):
        return {"status": "error", "message": f"Image file not found: {image_path}"}
    if not os.path.isfile(model_path):
        return {"status": "error", "message": f"Model file not found: {model_path}"}

    sess = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])
    inp = sess.get_inputs()[0]
    input_name = inp.name
    inp_shape = inp.shape
    # Dynamic input dimensions (e.g. 640x640 or 1024x1024)
    model_h = inp_shape[2] if len(inp_shape) > 2 and isinstance(inp_shape[2], int) else 640
    model_w = inp_shape[3] if len(inp_shape) > 3 and isinstance(inp_shape[3], int) else 640
    
    img = Image.open(image_path).convert('RGB')
    orig_w, orig_h = img.size
    
    img_resized = img.resize((model_w, model_h), Image.BILINEAR)
    arr = np.array(img_resized, dtype=np.float32) / 255.0
    tensor = np.transpose(arr, (2, 0, 1))[np.newaxis, ...]
    
    outs = sess.run(None, {input_name: tensor})
    raw_out = outs[0][0] # Shape: [channels, anchors] e.g. [8, 8400] or [7, 21504]
    
    # Transpose to [num_anchors, channels]
    preds = np.transpose(raw_out, (1, 0))
    
    # Coordinates: [xc, yc, w, h] followed by class scores
    num_classes = preds.shape[1] - 4
    boxes_norm = preds[:, :4]
    class_scores = preds[:, 4:4+num_classes]
    
    best_classes = np.argmax(class_scores, axis=1)
    best_scores = np.max(class_scores, axis=1)
    
    # Filter by confidence
    valid_mask = best_scores >= conf_thresh
    boxes_valid = boxes_norm[valid_mask]
    scores_valid = best_scores[valid_mask]
    classes_valid = best_classes[valid_mask]
    
    # Dynamic class names from ONNX model metadata
    class_names = {0: 'Microaneurysm', 1: 'Haemorrhage', 2: 'Hard Exudate', 3: 'Soft Exudate'}
    try:
        custom_meta = sess.get_modelmeta().custom_metadata_map
        if 'names' in custom_meta:
            import ast
            raw_names = ast.literal_eval(custom_meta['names'])
            class_names = {int(k): str(v) for k, v in raw_names.items()}
    except Exception:
        pass
    
    model_basename = os.path.basename(model_path)
    model_source_tag = "YOLOv8 (Roboflow)" if ("models 2" in model_path or "yolo_lesions" in model_path) else "YOLO11n (IDRiD)"
    
    # Compute retinal field-of-view (FOV) mask to reject detections outside the fundus
    gray_img = np.array(img.convert('L'))
    h_idx, w_idx = np.where(gray_img > 18)
    if len(h_idx) > 1000:
        cy_fov = (np.min(h_idx) + np.max(h_idx)) / 2.0
        cx_fov = (np.min(w_idx) + np.max(w_idx)) / 2.0
        rad_fov = max((np.max(h_idx) - np.min(h_idx)) / 2.0, (np.max(w_idx) - np.min(w_idx)) / 2.0) * 0.985
    else:
        cx_fov, cy_fov, rad_fov = orig_w / 2.0, orig_h / 2.0, min(orig_w, orig_h) / 2.0 * 0.985
    
    detections = []
    if len(scores_valid) > 0:
        scale_x = orig_w / float(model_w)
        scale_y = orig_h / float(model_h)
        
        xc = boxes_valid[:, 0] * scale_x
        yc = boxes_valid[:, 1] * scale_y
        bw = boxes_valid[:, 2] * scale_x
        bh = boxes_valid[:, 3] * scale_y
        
        x1 = np.maximum(0, xc - bw / 2.0)
        y1 = np.maximum(0, yc - bh / 2.0)
        x2 = np.minimum(orig_w, xc + bw / 2.0)
        y2 = np.minimum(orig_h, yc + bh / 2.0)
        
        pixel_boxes = np.stack([x1, y1, x2, y2], axis=1)
        
        # Per-class NMS
        for c_id in np.unique(classes_valid):
            c_mask = (classes_valid == c_id)
            c_boxes = pixel_boxes[c_mask]
            c_scores = scores_valid[c_mask]
            
            keep_idx = nms(c_boxes, c_scores, iou_thresh)
            for idx in keep_idx:
                box = c_boxes[idx]
                bcx = (box[0] + box[2]) / 2.0
                bcy = (box[1] + box[3]) / 2.0
                
                # Reject boxes outside image bounds
                if bcx < 0 or bcx >= orig_w or bcy < 0 or bcy >= orig_h:
                    continue
                # Reject boxes whose center lies in dark camera surround (< 20)
                if gray_img[int(bcy), int(bcx)] < 20:
                    continue
                # Reject boxes outside circular fundus FOV
                dist_to_center = np.sqrt((bcx - cx_fov)**2 + (bcy - cy_fov)**2)
                if dist_to_center > rad_fov:
                    continue
                
                clip_x1 = max(0.0, min(float(orig_w - 1), float(box[0])))
                clip_y1 = max(0.0, min(float(orig_h - 1), float(box[1])))
                clip_x2 = max(0.0, min(float(orig_w - 1), float(box[2])))
                clip_y2 = max(0.0, min(float(orig_h - 1), float(box[3])))
                
                detections.append({
                    "class_id": int(c_id),
                    "class_name": class_names.get(int(c_id), "Lesion"),
                    "confidence": float(c_scores[idx]),
                    "bbox": [clip_x1, clip_y1, clip_x2, clip_y2],
                    "model_source": model_source_tag
                })

    return {
        "status": "success",
        "model_name": model_basename,
        "model_source": model_source_tag,
        "num_detections": len(detections),
        "detections": detections,
        "original_dimensions": [orig_w, orig_h]
    }

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--task', choices=['classify', 'detect'], required=True)
    parser.add_argument('--image', required=True)
    parser.add_argument('--model', required=True)
    parser.add_argument('--conf', type=float, default=0.20)
    parser.add_argument('--iou', type=float, default=0.45)
    args = parser.parse_args()

    if args.task == 'classify':
        res = run_classifier(args.image, args.model)
    elif args.task == 'detect':
        res = run_detector(args.image, args.model, args.conf, args.iou)
    
    print(json.dumps(res, indent=2))
