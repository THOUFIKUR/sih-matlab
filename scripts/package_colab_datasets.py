"""
Script to create the two zip archives for Google Colab:
- D:\idrid_grading.zip
- D:\idrid_segmentation.zip
Ensures relative paths are preserved as:
  'B. Disease Grading/...'
  'A. Segmentation/...'
"""

import os
import zipfile
import time

def zip_directory(source_dir, output_zip, arcname_root):
    print(f"Creating {output_zip} from {source_dir}...")
    t0 = time.time()
    file_count = 0
    total_bytes = 0

    with zipfile.ZipFile(output_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipf:
        for root, dirs, files in os.walk(source_dir):
            for file in files:
                abs_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_path, os.path.dirname(source_dir))
                zipf.write(abs_path, rel_path)
                file_count += 1
                total_bytes += os.path.getsize(abs_path)
                if file_count % 100 == 0:
                    print(f"  Added {file_count} files...")

    duration = time.time() - t0
    zip_size_mb = os.path.getsize(output_zip) / (1024 * 1024)
    print(f"Completed {output_zip} in {duration:.1f}s!")
    print(f"  Total files: {file_count}, Original size: {total_bytes / (1024*1024):.1f} MB, Compressed size: {zip_size_mb:.1f} MB\n")

if __name__ == '__main__':
    # 1. IDRiD Grading
    grading_src = r"D:\sih2026\retino\data\idrid\B. Disease Grading"
    grading_zip = r"D:\idrid_grading.zip"
    zip_directory(grading_src, grading_zip, "B. Disease Grading")

    # 2. IDRiD Segmentation
    seg_src = r"D:\sih2026\retino\data\idrid\A. Segmentation"
    seg_zip = r"D:\idrid_segmentation.zip"
    zip_directory(seg_src, seg_zip, "A. Segmentation")
