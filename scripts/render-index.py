#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)
"""Render a minimal index.html listing the per-architecture repository zips."""

import html
import os
import sys

site_dir, base_url = sys.argv[1], sys.argv[2].rstrip('/')
rows = []
for arch in ('arm', 'aarch64', 'x86_64'):
    repo_dir = os.path.join(site_dir, arch, 'repository.alist.' + arch)
    svc_dir = os.path.join(site_dir, arch, 'service.alist')
    if not os.path.isdir(repo_dir):
        continue
    repo_zip = sorted(f for f in os.listdir(repo_dir) if f.endswith('.zip'))[-1]
    svc_zip = sorted(f for f in os.listdir(svc_dir) if f.endswith('.zip'))[-1]
    rows.append((arch, f'{base_url}/{arch}/repository.alist.{arch}/{repo_zip}',
                 f'{base_url}/{arch}/service.alist/{svc_zip}'))

print('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
      '<title>AList for CoreELEC</title>'
      '<style>body{font-family:sans-serif;max-width:48rem;margin:2rem auto;padding:0 1rem}'
      'table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:.4rem .8rem;text-align:left}</style>'
      '</head><body><h1>AList for CoreELEC / LibreELEC</h1>'
      '<p>Install the repository zip for your architecture once; Kodi then updates AList automatically. '
      'Architecture is shown in <code>/etc/os-release</code> (<code>COREELEC_ARCH</code> / <code>LIBREELEC_ARCH</code>).</p>'
      '<table><tr><th>Architecture</th><th>Repository add-on</th><th>Service add-on (manual install)</th></tr>')
for arch, repo_url, svc_url in rows:
    print(f'<tr><td>{arch}</td><td><a href="{html.escape(repo_url)}">{html.escape(os.path.basename(repo_url))}</a></td>'
          f'<td><a href="{html.escape(svc_url)}">{html.escape(os.path.basename(svc_url))}</a></td></tr>')
print('</table><p><a href="https://github.com/AlistGo/Alist-CoreELEC">Source and documentation</a></p></body></html>')
