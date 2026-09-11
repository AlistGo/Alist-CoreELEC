#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2019-present Team LibreELEC (https://libreelec.tv)
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)
#
# Stand-alone re-implementation of the add-on packaging steps from the
# CoreELEC build system (config/functions: create_addon_xml, and
# scripts/install_addon), so the add-on can be built without the full
# build tree. Download/verification flow follows AlistGo/Alist-FN (MIT).

set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: build-addon.sh <alist-tag-or-version> <arm|aarch64|x86_64|all> [output-directory]

Produces <output-directory>/<arch>/service.alist-<version>.zip

Environment:
  ALIST_ARCHIVE     optional pre-downloaded upstream .tar.gz (single arch only)
  ALIST_SHA256      expected SHA-256 of the archive; required unless ALLOW_UNVERIFIED=1
  ALLOW_UNVERIFIED  set to 1 to skip checksum verification (local testing only)
  UPSTREAM_REPOSITORY  owner/repo to download from (default: AlistGo/alist)
USAGE
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 2
fi

upstream_tag="$1"
target="$2"
output_dir="${3:-dist}"
upstream_repository="${UPSTREAM_REPOSITORY:-AlistGo/alist}"

[[ "$upstream_tag" == v* ]] || upstream_tag="v${upstream_tag}"
version="${upstream_tag#v}"

# Kodi accepts looser strings, but the repository generator enforces semver.
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid AList version: $version (expected X.Y.Z)" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
# Packing changes directory, so the output path must be absolute.
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
addon_id="service.alist"
addon_src="${repo_root}/addon/${addon_id}"

upstream_asset() {
  case "$1" in
    arm)     echo "alist-linux-musleabihf-armv7l.tar.gz" ;;
    aarch64) echo "alist-linux-musl-arm64.tar.gz" ;;
    x86_64)  echo "alist-linux-musl-amd64.tar.gz" ;;
    *)
      echo "Unsupported architecture: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
}

build_one() {
  local arch="$1"
  local asset asset_url work_dir addon_dir archive extract_dir arch_out zip_name

  asset="$(upstream_asset "$arch")"
  asset_url="https://github.com/${upstream_repository}/releases/download/${upstream_tag}/${asset}"

  work_dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${work_dir}'" RETURN

  addon_dir="${work_dir}/${addon_id}"
  archive="${work_dir}/${asset}"
  extract_dir="${work_dir}/extract"
  arch_out="${output_dir}/${arch}"
  mkdir -p "$addon_dir" "$extract_dir" "$arch_out"

  # --- upstream binary -----------------------------------------------------
  if [[ -n "${ALIST_ARCHIVE:-}" ]]; then
    cp "$ALIST_ARCHIVE" "$archive"
  else
    curl --fail --location --retry 3 --retry-all-errors \
      --output "$archive" "$asset_url"
  fi

  if [[ -n "${ALIST_SHA256:-}" ]]; then
    local actual_sha256
    actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
    if [[ "$actual_sha256" != "$ALIST_SHA256" ]]; then
      echo "SHA-256 mismatch for $asset" >&2
      echo "expected: $ALIST_SHA256" >&2
      echo "actual:   $actual_sha256" >&2
      exit 1
    fi
  elif [[ "${ALLOW_UNVERIFIED:-0}" != "1" ]]; then
    echo "ALIST_SHA256 is required (set ALLOW_UNVERIFIED=1 only for local testing)." >&2
    exit 1
  fi

  tar -xzf "$archive" -C "$extract_dir"
  if [[ ! -f "${extract_dir}/alist" ]]; then
    echo "Upstream archive does not contain the expected 'alist' executable." >&2
    exit 1
  fi

  # --- install_addon_source / install_addon_images ---------------------------
  cp -R "${addon_src}/." "$addon_dir/"
  rm -f "${addon_dir}/addon.xml.in"
  find "$addon_dir" \( -name '__pycache__' -o -name '*.pyc' -o -name '.DS_Store' \) -prune -exec rm -rf {} +
  install -m 0755 "${extract_dir}/alist" "${addon_dir}/bin/alist"
  chmod 0755 "${addon_dir}/bin/alist.start"

  mkdir -p "${addon_dir}/licenses"
  cp "${repo_root}/licenses/AList-AGPL-3.0.txt" "${addon_dir}/licenses/"
  cp "${repo_root}/LICENSE" "${addon_dir}/licenses/GPL-2.0.txt"
  cp "${repo_root}/THIRD_PARTY_NOTICES.md" "${addon_dir}/licenses/"

  # --- create_addon_xml ------------------------------------------------------
  local news_file
  news_file="$(mktemp)"
  {
    echo "AList ${version} (${arch})"
    if [[ -f "${addon_src}/changelog.txt" ]]; then
      sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "${addon_src}/changelog.txt"
    fi
  } > "$news_file"

  sed -e "s|@ADDON_VERSION@|${version}|g" \
      -e "s|@ALIST_VERSION@|${version}|g" \
      -e "/@PKG_ADDON_NEWS@/{
            r ${news_file}
            d
          }" \
      "${addon_src}/addon.xml.in" > "${addon_dir}/addon.xml"
  rm -f "$news_file"

  # settings-default.xml is what oe_setup_addon reads before the user has
  # opened the settings dialog once; derive it from resources/settings.xml.
  python3 "${script_dir}/settings-default.py" \
    "${addon_dir}/resources/settings.xml" > "${addon_dir}/settings-default.xml"

  # --- pack_addon -----------------------------------------------------------
  zip_name="${addon_id}-${version}.zip"
  rm -f "${arch_out}/${zip_name}"
  (
    cd "$work_dir"
    zip -q -r -X -9 "${arch_out}/${zip_name}" "${addon_id}" -x '*.DS_Store'
  )
  # Kodi repositories serve icon/changelog next to the archive.
  cp "${addon_dir}/addon.xml" "${arch_out}/addon.xml"
  cp "${addon_dir}/resources/icon.png" "${arch_out}/icon.png"
  cp "${addon_src}/changelog.txt" "${arch_out}/changelog-${version}.txt"

  shasum -a 256 "${arch_out}/${zip_name}"
  echo "Created ${arch_out}/${zip_name}"
}

case "$target" in
  all)
    if [[ -n "${ALIST_ARCHIVE:-}" ]]; then
      echo "ALIST_ARCHIVE cannot be combined with 'all'." >&2
      exit 2
    fi
    for arch in arm aarch64 x86_64; do
      build_one "$arch"
    done
    ;;
  *)
    build_one "$target"
    ;;
esac
