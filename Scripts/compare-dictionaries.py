#!/usr/bin/env python3
"""Compare complete SQLite dictionary content across SQLite runtime versions."""
import itertools
from pathlib import Path
import sqlite3
import sys


def compare(left, right):
    connections = [sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro', uri=True)
                   for path in (left, right)]
    try:
        for db in connections:
            if db.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
                raise ValueError('dictionary integrity check failed')
        for pragma in ('user_version', 'application_id', 'encoding'):
            if connections[0].execute(f'PRAGMA {pragma}').fetchall() != connections[1].execute(f'PRAGMA {pragma}').fetchall():
                raise ValueError(f'different {pragma}')
        query = 'SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name'
        schema = connections[0].execute(query).fetchall()
        if schema != connections[1].execute(query).fetchall():
            raise ValueError('different schema')
        for kind, name, _, _ in schema:
            if kind != 'table':
                continue
            quoted = '"' + name.replace('"', '""') + '"'
            # These dictionary tables all have rowids; compare them as well as
            # every stored field, including explicit candidate sequence numbers.
            rows = [db.execute(f'SELECT rowid,* FROM {quoted} ORDER BY rowid') for db in connections]
            missing = object()
            if any(a != b for a, b in itertools.zip_longest(*rows, fillvalue=missing)):
                raise ValueError(f'different rows or order: {name}')
    finally:
        for db in connections:
            db.close()


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: compare-dictionaries.py expected.sqlite3 actual.sqlite3')
    try:
        compare(*sys.argv[1:])
    except (ValueError, sqlite3.Error) as error:
        raise SystemExit(f'FAIL dictionary comparison: {error}')
    print('PASS complete dictionary schema, metadata, rows and order')
