#!/usr/bin/env python3
"""Deterministic offline conversion; source spelling retained, duplicate readings merged."""
import hashlib,json,re,sqlite3,sys,os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'Vendor/RimeCantonese'
manifest=json.loads((source/'manifest.json').read_text())
for name,sha in manifest['files'].items():
    if hashlib.sha256((source/name).read_bytes()).hexdigest()!=sha: raise SystemExit('Source checksum mismatch: '+name)
freq={}
for line in (source/'essay-cantonese.txt').read_text().splitlines():
    word,weight=line.split('\t');freq[word]=int(weight)
entries={};words={}
for name in ['jyut6ping3.chars.dict.yaml','jyut6ping3.words.dict.yaml']:
    body=(source/name).read_text().split('\n...\n',1)[1]
    for line in body.splitlines():
        if not line or line.startswith('#'):continue
        parts=line.split('\t')
        if len(parts)<2:continue
        word,reading=parts[:2]
        if not re.fullmatch(r'[a-z]+[1-6]( [a-z]+[1-6])*',reading):continue
        score=float(freq.get(word,0))
        if len(parts)>2 and parts[2].endswith('%'):score*=float(parts[2][:-1])/100
        code=reading.replace(' ','');plain=re.sub('[1-6]','',code)
        key=(word,code)
        if key not in entries:entries[key]=(plain,score,len(entries))
        words.setdefault(word,(freq.get(word,0),len(words)))
for line in (root/'Resources/CantoneseSupplement.tsv').read_text().splitlines():
    if not line or line.startswith('#'):continue
    word,reading=line.split('\t');code=reading.replace(' ','');plain=re.sub('[1-6]','',code)
    entries.setdefault((word,code),(plain,float(freq.get(word,0)),len(entries)))
    words.setdefault(word,(freq.get(word,0),len(words)))
for line in (root/'Resources/Phrases.txt').read_text().splitlines():
    if line and not line.startswith('#'):words.setdefault(line,(freq.get(line,0),len(words)))
out=Path(sys.argv[1]) if len(sys.argv)>1 else root/'Resources/Cantonese.sqlite3'
staging=out.with_suffix('.building')
if staging.exists():staging.unlink()
db=sqlite3.connect(staging)
db.executescript('CREATE TABLE readings(word TEXT, toned TEXT, plain TEXT, score REAL, seq INTEGER); CREATE TABLE phrases(prefix TEXT,word TEXT,score INTEGER,seq INTEGER);')
db.executemany('INSERT INTO readings VALUES(?,?,?,?,?)',[(w,c,p,s,n) for (w,c),(p,s,n) in entries.items()])
db.executemany('INSERT INTO phrases VALUES(?,?,?,?)',[(w[:i],w,s,n) for w,(s,n) in words.items() if 2<=len(w)<=12 for i in range(1,len(w))])
db.executescript('CREATE INDEX toned_lookup ON readings(toned,score DESC,seq); CREATE INDEX plain_lookup ON readings(plain,score DESC,seq); CREATE INDEX phrase_lookup ON phrases(prefix,score DESC,seq); PRAGMA user_version=1;')
db.commit();db.execute('VACUUM');db.close();os.replace(staging,out)
print(f'Cantonese: {len(entries)} readings, {sum(2<=len(w)<=12 for w in words)} phrase words')
