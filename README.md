# Alist-CoreELEC

[English](#english) | [中文](#中文)

Packages the official [AList](https://github.com/AlistGo/alist) static binary as a Kodi service add-on (`service.alist`) for CoreELEC and LibreELEC, and publishes a Kodi repository so devices update automatically. Builds are triggered by upstream AList releases.

---

## English

### Install

1. Find your architecture on the device: `grep _ARCH /etc/os-release` shows `COREELEC_ARCH="Amlogic-ne.aarch64"` or `LIBREELEC_ARCH="Generic.x86_64"`; the suffix is the architecture.

   | Architecture | Typical build |
   |---|---|
   | `arm` | CoreELEC Amlogic-ng (32-bit userspace) |
   | `aarch64` | CoreELEC Amlogic-ne (64-bit userspace) |
   | `x86_64` | LibreELEC Generic |

2. Download `repository.alist.<arch>-<version>.zip` from the [latest release](https://github.com/AlistGo/Alist-CoreELEC/releases/latest) or the [repository index](https://alistgo.github.io/Alist-CoreELEC/).
3. In Kodi enable **Settings → System → Add-ons → Unknown sources**, then **Add-ons → Install from zip file** and pick the repository zip.
4. **Install from repository → AList Repository → Services → AList**. Kodi installs and starts the service and will offer updates when a new AList version is packaged.

To skip the repository, install `service.alist-<version>-<arch>.zip` from the release directly; updates are then manual.

### Use

- Web UI and WebDAV: `http://<device-ip>:5244/`
- Login: `admin` / password from the add-on settings (default `coreelec`). Change it in **Add-ons → My add-ons → Services → AList → Configure**; the service restarts and applies it.
- Data (config, SQLite database, logs): `/storage/.kodi/userdata/addon_data/service.alist/data`. Upgrades keep this folder.
- Service control over SSH: `systemctl status|restart service.alist`, logs with `journalctl -u service.alist`.

### Automatic builds

The `Sync AList release` workflow runs hourly. When AList publishes a stable release that this repository has not packaged yet it:

1. reads the upstream release metadata and per-asset SHA-256 digests;
2. downloads and verifies the `musleabihf-armv7l`, `musl-arm64` and `musl-amd64` archives;
3. builds one `service.alist-<version>.zip` per architecture;
4. creates the GitHub Release `alist-v<version>` with the add-on zips, the repository add-on zips and `SHA256SUMS`;
5. regenerates the Kodi repository (`addons.xml.gz` and zips) and deploys it to GitHub Pages.

The workflow can also be run manually from the Actions tab with a specific AList version and an optional `force` flag to rebuild an existing release. Only the newest upstream version is ever deployed to the repository index, so a forced rebuild of an older version cannot downgrade users.

GitHub Actions cannot subscribe to another repository's release events, so polling is used; builds usually start within an hour of the upstream release.

### Local build

Requires `bash`, `curl`, `zip`, `unzip`, `xmllint`, `python3` (and `msgfmt` for the translation check).

```bash
./scripts/check.sh                                   # static checks + offline packaging test
./scripts/build-addon.sh v3.64.0 aarch64 dist        # one architecture
./scripts/build-addon.sh v3.64.0 all dist            # all architectures
./scripts/build-repository.sh dist site https://alistgo.github.io/Alist-CoreELEC
```

`build-addon.sh` verifies the upstream archive against `ALIST_SHA256` (taken from the GitHub release API in CI). For local experiments with a pre-downloaded archive set `ALIST_ARCHIVE=/path/to/alist-linux-musl-arm64.tar.gz` and either `ALIST_SHA256` or `ALLOW_UNVERIFIED=1`.

### Layout

```text
addon/service.alist/        add-on source (rendered addon.xml, start script, systemd unit, settings, strings)
addon/repository.alist/     Kodi repository add-on template (one instance per architecture)
scripts/build-addon.sh      download, verify and pack the service add-on
scripts/build-repository.sh generate the static Kodi repository via tools/create_repository.py
scripts/check.sh            static checks and the offline packaging test
tools/create_repository.py  vendored Kodi repository generator (Chad Parry, GPL-2.0)
.github/workflows/          upstream release polling, build, release and Pages deployment
```

### Licence

The add-on and build scripts are GPL-2.0-only, derived from the LibreELEC/CoreELEC `service.filebrowser` add-on and build system, and from Chad Parry's `create_repository.py`. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). AList itself is AGPL-3.0 and is redistributed unmodified with its licence inside every zip.

---

## 中文

### 安装

1. 在设备上确认架构：`grep _ARCH /etc/os-release` 会显示 `COREELEC_ARCH="Amlogic-ne.aarch64"` 或 `LIBREELEC_ARCH="Generic.x86_64"`，末尾即架构名。

   | 架构 | 常见系统 |
   |---|---|
   | `arm` | CoreELEC Amlogic-ng（32 位用户空间） |
   | `aarch64` | CoreELEC Amlogic-ne（64 位用户空间） |
   | `x86_64` | LibreELEC Generic |

2. 从[最新 Release](https://github.com/AlistGo/Alist-CoreELEC/releases/latest) 或[仓库索引页](https://alistgo.github.io/Alist-CoreELEC/)下载 `repository.alist.<架构>-<版本>.zip`。
3. Kodi 中开启 **设置 → 系统 → 插件 → 未知来源**，然后 **插件 → 从 zip 文件安装**，选择仓库 zip。
4. **从库安装 → AList Repository → 服务 → AList**。Kodi 会安装并启动服务，之后有新版本时自动提示更新。

不想用仓库的话，直接安装 Release 中的 `service.alist-<版本>-<架构>.zip`，升级需手动。

### 使用

- 网页与 WebDAV：`http://<设备IP>:5244/`
- 登录：用户名 `admin`，密码见插件设置（默认 `coreelec`）。在 **插件 → 我的插件 → 服务 → AList → 配置** 中修改，服务会自动重启并生效。
- 数据目录（配置、SQLite 数据库、日志）：`/storage/.kodi/userdata/addon_data/service.alist/data`，升级不丢失。
- SSH 下管理：`systemctl status|restart service.alist`，日志 `journalctl -u service.alist`。

### 自动构建

`Sync AList release` 工作流每小时运行一次。发现 AList 发布了本仓库尚未打包的稳定版后：

1. 读取上游 Release 元数据与各资产的 SHA-256；
2. 下载并校验 `musleabihf-armv7l`、`musl-arm64`、`musl-amd64` 三个压缩包；
3. 每个架构构建一个 `service.alist-<版本>.zip`；
4. 创建 GitHub Release `alist-v<版本>`，附带插件 zip、仓库插件 zip 与 `SHA256SUMS`；
5. 重新生成 Kodi 仓库（`addons.xml.gz` 与 zip）并部署到 GitHub Pages。

也可以在 Actions 页手动运行，指定 AList 版本，`force` 可覆盖已有 Release。只有上游最新版本才会部署到仓库索引，强制重建旧版本不会让用户降级。

GitHub Actions 无法订阅其他仓库的 Release 事件，因此采用定时轮询，通常在上游发布后一小时内开始构建。

### 本地构建

需要 `bash`、`curl`、`zip`、`unzip`、`xmllint`、`python3`（翻译检查需 `msgfmt`）。

```bash
./scripts/check.sh                                   # 静态检查 + 离线打包测试
./scripts/build-addon.sh v3.64.0 aarch64 dist        # 单架构
./scripts/build-addon.sh v3.64.0 all dist            # 全部架构
./scripts/build-repository.sh dist site https://alistgo.github.io/Alist-CoreELEC
```

`build-addon.sh` 会用 `ALIST_SHA256` 校验上游压缩包（CI 中取自 GitHub Release API）。本地用已下载的包实验时，设置 `ALIST_ARCHIVE=/path/to/alist-linux-musl-arm64.tar.gz`，并提供 `ALIST_SHA256` 或 `ALLOW_UNVERIFIED=1`。

### 目录结构

```text
addon/service.alist/        插件源码（addon.xml 模板、启动脚本、systemd 单元、设置、翻译）
addon/repository.alist/     Kodi 仓库插件模板（每个架构渲染一份）
scripts/build-addon.sh      下载、校验并打包服务插件
scripts/build-repository.sh 通过 tools/create_repository.py 生成静态 Kodi 仓库
scripts/check.sh            静态检查与离线打包测试
tools/create_repository.py  原样引入的 Kodi 仓库生成脚本（Chad Parry，GPL-2.0）
.github/workflows/          上游版本轮询、构建、发布与 Pages 部署
```

### 许可

插件与构建脚本采用 GPL-2.0-only，源自 LibreELEC/CoreELEC 的 `service.filebrowser` 插件与构建系统，以及 Chad Parry 的 `create_repository.py`，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。AList 本身为 AGPL-3.0，未经修改随包分发并附带许可证。
