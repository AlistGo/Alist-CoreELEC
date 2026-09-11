#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)
"""Emit a settings-default.xml (Kodi settings format version 2) from a
resources/settings.xml definition, so oe_setup_addon can export defaults
before the user has ever opened the add-on settings dialog."""

import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
out = ET.Element('settings', {'version': '2'})
for setting in root.iter('setting'):
    if setting.get('type') == 'action':
        continue
    default = setting.find('default')
    node = ET.SubElement(out, 'setting', {'id': setting.get('id'), 'default': 'true'})
    node.text = default.text if default is not None and default.text else ''
sys.stdout.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
sys.stdout.write(ET.tostring(out, encoding='unicode') + '\n')
