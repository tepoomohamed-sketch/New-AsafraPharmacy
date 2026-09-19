#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
sys.stdout.reconfigure(encoding='utf-8')

src = r'c:\Users\HP\Documents\Claude\Projects\asafra pharmacy\سجل الصيدلية - متعدد المستخدمين.html'

# Read as bytes then decode carefully
with open(src, 'rb') as f:
    raw_bytes = f.read()

c = raw_bytes.decode('utf-8', errors='replace')

# ─────────────────────────────────────────────────────────────────────────────
# Find the corrupt block
# ─────────────────────────────────────────────────────────────────────────────
corrupt_start_marker = "const mR=entries.filter(e=>e.date?.startsWith(m)&&e.type==='      // \u2550\u2550 \u062f\u0627\u0644\u0629 \u062a\u062d\u0648\u064a\u0644"
corrupt_end_marker   = "return '';\n      }\\u064a</td>"

idx_s = c.find(corrupt_start_marker)
idx_e = c.find(corrupt_end_marker)

print(f"Corrupt start: {idx_s}, end: {idx_e}")

if idx_s == -1 or idx_e == -1:
    # Try a simpler marker
    corrupt_start_marker2 = "&&e.type==='      //"
    idx_s = c.find(corrupt_start_marker2)
    print(f"Alt start: {idx_s}")
    if idx_s != -1:
        # Walk back to find real start of the line
        sol = c.rfind('\n', 0, idx_s) + 1
        print(f"Start of line: {sol}")
        print(repr(c[sol:sol+80]))

idx_e_full = idx_e + len(corrupt_end_marker)

# Find any surrogate characters around the region
surr_idx = -1
for i, ch in enumerate(c):
    if 0xD800 <= ord(ch) <= 0xDFFF:
        if surr_idx == -1:
            surr_idx = i
print(f"First surrogate at: {surr_idx}")
if surr_idx != -1:
    print(repr(c[surr_idx-20:surr_idx+20]))
