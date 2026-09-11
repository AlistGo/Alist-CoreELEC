# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2016-present Team LibreELEC (https://libreelec.tv)
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)
#
# Derived from the LibreELEC/CoreELEC service.filebrowser add-on.

import subprocess
import xbmc
import xbmcaddon


class Monitor(xbmc.Monitor):

    def __init__(self, *args, **kwargs):
        xbmc.Monitor.__init__(self)
        self.id = xbmcaddon.Addon().getAddonInfo('id')

    def onSettingsChanged(self):
        subprocess.call(['systemctl', 'restart', self.id])


if __name__ == '__main__':
    Monitor().waitForAbort()
