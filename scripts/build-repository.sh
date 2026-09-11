#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)
#
# Builds the per-architecture Kodi repository add-ons and the static site
# (addons.xml.gz + zips) using tools/create_repository.py
# (Copyright 2016-2022 Chad Parry, GPL-2.0).

set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: build-repository.sh <dist-directory> <site-directory> <base-url>

  dist-directory   output of build-addon.sh (contains <arch>/service.alist-*.zip)
  site-directory   where the static Kodi repository is written
  base-url         public URL of site-directory, e.g. https://alistgo.github.io/Alist-CoreELEC
USAGE
}

if [[ $# -ne 3 ]]; then
  usage >&2
  exit 2
fi

dist_dir="$1"
site_dir="$2"
base_url="${3%/}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
repo_src="${repo_root}/addon/repository.alist"

if [[ ! "$base_url" =~ ^https?:// ]]; then
  echo "base-url must be an absolute http(s) URL: $base_url" >&2
  exit 2
fi

mkdir -p "$site_dir"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

built=0
for arch in arm aarch64 x86_64; do
  arch_dist="${dist_dir}/${arch}"
  [[ -d "$arch_dist" ]] || continue

  service_zip="$(find "$arch_dist" -maxdepth 1 -type f -name 'service.alist-*.zip' -print -quit)"
  if [[ -z "$service_zip" ]]; then
    echo "No service.alist zip found in $arch_dist" >&2
    exit 1
  fi

  repo_id="repository.alist.${arch}"
  repo_dir="${work_dir}/${repo_id}"
  mkdir -p "${repo_dir}/resources"
  sed -e "s|@ARCH@|${arch}|g" -e "s|@BASE_URL@|${base_url}|g" \
    "${repo_src}/addon.xml.in" > "${repo_dir}/addon.xml"
  cp "${repo_src}/resources/icon.png" "${repo_dir}/resources/icon.png"

  arch_site="${site_dir}/${arch}"
  rm -rf "$arch_site"
  mkdir -p "$arch_site"
  python3 "${repo_root}/tools/create_repository.py" \
    --datadir "$arch_site" --compressed --no-parallel \
    "$service_zip" "$repo_dir"

  # create_repository.py only extracts a legacy root-level icon.png. Kodi 17+
  # resolves <assets> paths relative to the datadir, so publish resources/
  # for both add-ons (mirrors scripts/install_addon in the CoreELEC build).
  python3 "${script_dir}/publish-assets.py" "$service_zip" "${arch_site}/service.alist"
  python3 "${script_dir}/publish-assets.py" "${arch_site}/${repo_id}/${repo_id}-"*.zip "${arch_site}/${repo_id}"

  # Ship the repository zip next to the service zip in dist/ too, so the
  # GitHub Release carries both.
  cp "${arch_site}/${repo_id}/${repo_id}-"*.zip "$arch_dist/"
  built=$((built + 1))
done

if [[ "$built" -eq 0 ]]; then
  echo "Nothing built: $dist_dir has no <arch> directories." >&2
  exit 1
fi

python3 "${script_dir}/render-index.py" "$site_dir" "$base_url" > "${site_dir}/index.html"
touch "${site_dir}/.nojekyll"
echo "Repository site written to ${site_dir}"
