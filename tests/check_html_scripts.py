#!/usr/bin/env python3
"""Extract inline JavaScript from index.html and run Node's syntax checker."""
from pathlib import Path
import re
import subprocess
import tempfile
import sys

html = Path("index.html").read_text(encoding="utf-8")
scripts = re.findall(r"<script\b([^>]*)>([\s\S]*?)</script\s*>", html, re.IGNORECASE)
checked = 0
with tempfile.TemporaryDirectory() as tmp:
    for index, (attrs, source) in enumerate(scripts):
        if re.search(r"\bsrc\s*=", attrs, re.IGNORECASE):
            continue
        kind = re.search(r"""\btype\s*=\s*["']?([^"'\s>]+)""", attrs, re.IGNORECASE)
        if kind and kind.group(1).lower() not in ("text/javascript", "application/javascript", "module"):
            continue
        path = Path(tmp) / f"inline-{index}.js"
        path.write_text(source, encoding="utf-8")
        result = subprocess.run(["node", "--check", str(path)], text=True, capture_output=True)
        if result.returncode:
            print(f"JavaScript syntax error in inline script #{index}:")
            print(result.stdout)
            print(result.stderr)
            sys.exit(result.returncode)
        checked += 1
print(f"PASS: syntax checked {checked} inline JavaScript block(s).")
