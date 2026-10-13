#!/usr/bin/env python3
"""Fetch only the pinned CC-BY resources; never fetched during app runtime."""
import hashlib,json,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'Vendor/RimeCantonese'
revision='259f0e48bba840c3a2e0d117539e96937f3d89bc'
files=['jyut6ping3.chars.dict.yaml','jyut6ping3.words.dict.yaml','essay-cantonese.txt','LICENSE-CC-BY','README.md']
root.mkdir(parents=True,exist_ok=True)
manifest={'repository':'https://github.com/rime/rime-cantonese','revision':revision,'license':'CC-BY-4.0','files':{}}
for name in files:
    data=urllib.request.urlopen(f'https://raw.githubusercontent.com/rime/rime-cantonese/{revision}/{name}',timeout=60).read()
    (root/name).write_bytes(data);manifest['files'][name]=hashlib.sha256(data).hexdigest()
(root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Fetched pinned Rime Cantonese resources')
