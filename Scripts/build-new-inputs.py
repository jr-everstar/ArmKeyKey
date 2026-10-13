#!/usr/bin/env python3
"""Build pinned Cangjie 5 and Mandarin data offline. Never modify vendor inputs."""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def verify():
    for name in ('Cangjie5', 'McBopomofo'):
        folder = ROOT / 'Vendor' / name
        manifest = json.loads((folder / 'manifest.json').read_text())
        for entry in manifest['files']:
            path = folder / entry['path']
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
                raise ValueError(f'Changed pinned input: {path}')

def cangjie(path):
    records, seen = [], set()
    started = False
    for line in (ROOT / 'Vendor/Cangjie5/Cangjie5_HK.txt').read_text().splitlines():
        if line.startswith('漢字\t'):
            started = True
            continue
        if not started or not line.strip() or line.startswith('---'):
            continue
        fields = line.split('\t')
        if len(fields) < 2 or not re.fullmatch('[a-z]{1,5}', fields[1]) or len(fields[0]) != 1:
            raise ValueError(f'Unsupported Cangjie row: {line}')
        pair = (fields[1], fields[0])
        if pair not in seen:
            records.append(pair)
            seen.add(pair)
    if len(records) < 100000:
        raise ValueError('Cangjie data unexpectedly incomplete')
    with sqlite3.connect(path) as db:
        db.execute('DROP TABLE IF EXISTS "Generic-cj5-cin"')
        db.execute('CREATE TABLE "Generic-cj5-cin" (key TEXT NOT NULL, value TEXT NOT NULL, seq INTEGER PRIMARY KEY)')
        props = db.execute('SELECT key,value FROM "Generic-cj-cin" WHERE substr(key,1,11)=\'__property_\' ORDER BY seq').fetchall()
        for i, (key, value) in enumerate(props + records):
            if key in ('__property_cname', '__property_tcname', '__property_scname', '__property_ename'):
                value = '倉頡五代（五代補完香港版）'
            db.execute('INSERT INTO "Generic-cj5-cin" VALUES (?,?,?)', (key, value, i))
        db.execute('CREATE INDEX "Generic-cj5-cin-key" ON "Generic-cj5-cin" (key,seq)')
    print(f'PASS Cangjie 5: {len(records)} unique mappings')

def mandarin(path):
    path = Path(path).resolve()
    with tempfile.TemporaryDirectory(prefix='ArmKeyKey-Mandarin-') as folder:
        work = Path(folder) / 'Data'
        shutil.copytree(ROOT / 'Vendor/McBopomofo/Source/Data', work)
        def run(module, *args):
            subprocess.run([sys.executable, '-m', 'curation.' + module, *args], cwd=work, check=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE':'1'})
        run('builders.frequency_builder')
        run('compilers.plain_bpmf_compiler', '--bpmf_base', 'BPMFBase.txt', '--punctuations', 'BPMFPunctuations.txt', '--output', 'plain.txt')
        args = []
        for key, file in [('heterophony1','heterophony1.list'),('heterophony2','heterophony2.list'),('heterophony3','heterophony3.list'),('phrase_freq','PhraseFreq.txt'),('bpmf_mappings','BPMFMappings.txt'),('bpmf_base','BPMFBase.txt'),('punctuations','BPMFPunctuations.txt'),('symbols','Symbols.txt'),('macros','Macros.txt')]:
            args += ['--'+key,file]
        run('compilers.main_compiler', *args, '--output', 'raw.txt')
        run('compilers.postprocess', '--input', 'raw.txt', '--directive', 'Postprocess.txt', '--output', 'smart.txt')
        staged = Path(folder) / 'Mandarin.sqlite3'
        with sqlite3.connect(staged) as db:
            for table in ('plain','smart'):
                db.execute(f'CREATE TABLE {table} (key TEXT NOT NULL,value TEXT NOT NULL,score REAL NOT NULL,seq INTEGER PRIMARY KEY)')
                rows, seen, excluded = [], set(), []
                for line in (work / (table+'.txt')).read_text().splitlines():
                    if not line or line.startswith('#'):
                        continue
                    reading = line.split()[0]
                    # Only phonetic entries. Macros/symbol modes are not exposed in ArmKeyKey.
                    if not re.fullmatch('[\u3105-\u3129ˊˇˋ˙-]+', reading):
                        continue
                    reading, value, score = line.split()
                    if not math.isfinite(float(score)):
                        raise ValueError('Non-finite Mandarin score')
                    if len(value) != len(reading.split('-')):
                        excluded.append(line)
                        continue
                    if (reading,value) in seen:
                        continue
                    seen.add((reading,value))
                    rows.append((reading,value,float(score),len(rows)))
                if len(rows) < 10000:
                    raise ValueError('Mandarin data unexpectedly incomplete')
                db.executemany(f'INSERT INTO {table} VALUES (?,?,?,?)',rows)
                db.execute(f'CREATE INDEX {table}_key ON {table}(key,seq)')
                print(f'PASS Mandarin {table}: {len(rows)} unique mappings; excluded {len(excluded)} non-aligned symbol/variant mappings')
                for line in excluded:
                    print('EXCLUDED non-aligned:',line)
            db.execute('PRAGMA user_version=1')
        path.parent.mkdir(parents=True,exist_ok=True)
        # Stage on destination filesystem for atomic replacement.
        dest = path.with_suffix('.building')
        shutil.copyfile(staged,dest)
        dest.replace(path)

if __name__ == '__main__':
    verify()
    cangjie(sys.argv[1] if len(sys.argv)>1 else ROOT/'Resources/Dictionary.sqlite3')
    mandarin(sys.argv[2] if len(sys.argv)>2 else ROOT/'Resources/Mandarin.sqlite3')
