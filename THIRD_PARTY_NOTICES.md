# Third-party notices

This repository packages an unmodified AList binary and reuses packaging code
from other open-source projects. The original copyright notices are kept in
each file header.

## AList

The generated add-ons redistribute the official static musl builds from
[AlistGo/alist releases](https://github.com/AlistGo/alist/releases). AList is
licensed under the GNU Affero General Public License v3.0. Every add-on zip
carries the upstream licence at `licenses/AList-AGPL-3.0.txt`; corresponding
source is available from the upstream release tag linked in each GitHub
Release. The add-on icon is the official AList logo.

## LibreELEC / CoreELEC add-on sources (GPL-2.0-only)

Copyright (C) 2016-present Team LibreELEC (https://libreelec.tv)

The add-on skeleton is derived from the `service.filebrowser` add-on and the
add-on templates in the CoreELEC build system
(https://github.com/CoreELEC/CoreELEC, branch `coreelec-22`):

| File in this repository | Origin |
|---|---|
| `addon/service.alist/default.py` | `packages/addons/service/filebrowser/source/default.py` |
| `addon/service.alist/bin/alist.start` | `packages/addons/service/filebrowser/source/bin/filebrowser.start` |
| `addon/service.alist/system.d/service.alist.service` | `packages/addons/service/filebrowser/source/system.d/service.filebrowser.service` |
| `addon/service.alist/resources/settings.xml` | `packages/addons/service/filebrowser/source/resources/settings.xml` |
| `addon/service.alist/addon.xml.in` | `config/addon/xbmc.service.xml` |
| `scripts/build-addon.sh` | re-implementation of `create_addon_xml()` in `config/functions` and `scripts/install_addon` |

## create_repository.py (GPL-2.0)

Copyright 2016-2022 Chad Parry (github@chad.parry.org)

`tools/create_repository.py` is vendored unchanged from
https://github.com/chadparry/kodi-repository.chad.parry.org (version 2.3.8).
The repository add-on layout in `addon/repository.alist/addon.xml.in`
follows the same project.

## Alist-FN (MIT)

Copyright (c) 2026 Alist-FN contributors

The upstream release detection, checksum verification and GitHub Release
publishing flow in `.github/workflows/sync-alist.yml` and the
download/verify section of `scripts/build-addon.sh` are adapted from
https://github.com/AlistGo/Alist-FN.
