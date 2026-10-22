import numpy as np
import onnxruntime as ort
from PIL import Image
import glob
import os

def test_yolo(model_path, img_paths):
    sess = ort.InferenceSession(model_path)
    inp = sess.get_inputs()[0]
    inp_name = inp.name
    inp_shape = inp.shape # e.g. [1, 3, 1024, 1024] or [1, 3, 640, 640]
    h, w = inp_shape[2], inp_shape[3]
    print(f"\n--- Testing {model_path} (Input: {w}x{h}) ---")
    
    meta = sess.get_modelmeta().custom_metadata_map
    names = eval(meta.get('names', '{}'))
    print(f"Classes: {names}")
    
    for p in img_paths[:5]:
        img = Image.open(p).convert('RGB')
        orig_w, orig_h = img.size
        # Resize without letterbox for quick test
        img_resized = img.resize((w, h))
        arr = np.array(img_resized).astype(np.float32) / 255.0
        arr = np.transpose(arr, (2, 0, 1)) # CHW
        arr = np.expand_dims(arr, 0) # NCHW
        
        outs = sess.run(None, {inp_name: arr})
        out0 = outs[0] # [1, num_channels, num_anchors]
        print(f"File: {os.path.basename(p)}, Output shape: {out0.shape}")
        
        # Transpose to [num_anchors, num_channels]
        preds = out0[0].T
        num_classes = len(names)
        # Bounding box coords: cx, cy, bw, bh
        # Class scores start at index 4
        boxes = preds[:, :4]
        scores = preds[:, 4:4+num_classes]
        max_scores = np.max(scores, axis=1)
        best_cls = np.argmax(scores, axis=1)
        
        # Check conf > 0.15
        mask = max_scores > 0.15
        num_dets = np.sum(mask)
        print(f"  Detections with conf > 0.15: {num_dets}")
        if num_dets > 0:
            top_indices = np.argsort(max_scores[mask])[::-1][:5]
            for idx in top_indices:
                cls_id = best_cls[mask][idx]
                score = max_scores[mask][idx]
                cls_name = names.get(cls_id, str(cls_id))
                print(f"    Top det: {cls_name} (conf={score:.3f})")

img_files = glob.glob('data/aptos2019/train_images/*.png')[:5]
test_yolo('data/models/yolo11n_lesions_scratch.onnx', img_files)
test_yolo('data/models 2/yolo_lesions.onnx', img_files)
