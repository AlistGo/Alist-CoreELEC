#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)
"""Copy resources/*.png|*.jpg (icon, fanart, screenshots) out of an add-on zip
into <target>/resources so a Kodi repository can serve them next to the zip."""

import os
import sys
import zipfile

zip_path, target = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as archive:
    for name in archive.namelist():
        parts = name.split('/')
        if len(parts) != 3 or parts[1] != 'resources':
            continue
        if not parts[2].lower().endswith(('.png', '.jpg')):
            continue
        os.makedirs(os.path.join(target, 'resources'), exist_ok=True)
        with archive.open(name) as src, \
                open(os.path.join(target, 'resources', parts[2]), 'wb') as dst:
            dst.write(src.read())
