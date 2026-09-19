#!/usr/bin/env python3
"""Gộp CLMCA.mq5 + CLMCACore.mqh thành MỘT file phát hành: release/CLMCA.mq5.
Build bundle: inline CLMCACore.mqh into CLMCA.mq5 -> release/CLMCA.mq5 (single file for users).
Nguồn sửa vẫn là MQL5/Experts/CLMCA/; KHÔNG sửa tay file trong release/."""
import hashlib, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
src = root / "MQL5/Experts/CLMCA"
ea = (src / "CLMCA.mq5").read_text(encoding="utf-8")
core = (src / "CLMCACore.mqh").read_text(encoding="utf-8")
line = '#include "CLMCACore.mqh"'
assert ea.count(line) == 1, "CLMCA.mq5 phải có đúng 1 dòng include core"
assert '#include "' not in core, "core không được include file cục bộ khác"
core_sha = hashlib.sha256(core.encode()).hexdigest()[:12]
ea_sha = hashlib.sha256(ea.encode()).hexdigest()[:12]
block = (f"// ===== BEGIN CLMCACore.mqh (sha256 {core_sha}) — sinh tự động, đừng sửa tay =====\n"
         f"{core.rstrip()}\n// ===== END CLMCACore.mqh =====")
header = (f"// BẢN PHÁT HÀNH MỘT FILE · SINGLE-FILE RELEASE — sinh bởi tools/bundle.py từ CLMCA.mq5 (sha256 {ea_sha}).\n"
          "// Sửa mã ở MQL5/Experts/CLMCA/, rồi chạy lại tools/bundle.py.\n")
out = root / "release/CLMCA.mq5"
out.parent.mkdir(exist_ok=True)
out.write_text(header + ea.replace(line, block), encoding="utf-8")
print(out, out.stat().st_size, "bytes")
