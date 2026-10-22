import csv
import numpy as np
import onnxruntime as ort
from PIL import Image
import os

with open('data/aptos2019/train.csv', 'r') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

print('APTOS Train rows:', len(rows))

# Sample 5 images per class (25 images total)
samples = []
for diag in range(5):
    count = 0
    for row in rows:
        if int(row['diagnosis']) == diag:
            p = os.path.join('data/aptos2019/train_images', str(row['id_code']) + '.png')
            if os.path.exists(p):
                samples.append((p, diag))
                count += 1
                if count >= 5:
                    break


print('Total samples selected for testing:', len(samples))

def preprocess_clf(img_path, size=224):
    img = Image.open(img_path).convert('RGB').resize((size, size))
    arr = np.array(img).astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    arr = (arr - mean) / std
    arr = np.transpose(arr, (2, 0, 1)) # CHW
    return np.expand_dims(arr, 0) # NCHW

# Model 1
sess1 = ort.InferenceSession('data/models/retina_efficientnet_b0_scratch.onnx')
inp1 = sess1.get_inputs()[0].name
preds1, trues = [], []
for p, true_cls in samples:
    x = preprocess_clf(p)
    out = sess1.run(None, {inp1: x})[0]
    preds1.append(int(np.argmax(out[0])))
    trues.append(true_cls)

acc1 = np.mean(np.array(preds1) == np.array(trues))
print(f'Model 1 (retina_efficientnet_b0_scratch.onnx) Acc: {acc1:.1%}')
print('Model 1 preds:', preds1)
print('True labels:  ', trues)

# Model 2
sess2 = ort.InferenceSession('data/models 2/retina_model.onnx')
inp2 = sess2.get_inputs()[0].name
preds2, probs2 = [], []
for p, true_cls in samples:
    x = preprocess_clf(p)
    outs = sess2.run(None, {inp2: x})
    logits = outs[0][0]
    exp_l = np.exp(logits - np.max(logits))
    prob = exp_l / np.sum(exp_l)
    preds2.append(int(np.argmax(prob)))
    probs2.append(prob)

acc2 = np.mean(np.array(preds2) == np.array(trues))
print(f'Model 2 (models 2/retina_model.onnx) Acc: {acc2:.1%}')
print('Model 2 preds:', preds2)
print('Model 2 sample logits first 3:\n', [list(np.round(p, 3)) for p in probs2[:3]])
