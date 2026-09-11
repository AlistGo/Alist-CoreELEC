#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)
#
# End-to-end packaging test without network access: a stub 'alist' binary is
# packed through build-addon.sh and build-repository.sh, then the resulting
# zips and repository metadata are inspected.

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Fake upstream archive: tar.gz containing an executable named 'alist'.
mkdir -p "$tmp/stub"
cat > "$tmp/stub/alist" <<'STUB'
#!/bin/sh
echo "stub alist $*"
STUB
chmod 0755 "$tmp/stub/alist"
tar -czf "$tmp/alist-stub.tar.gz" -C "$tmp/stub" alist
sha256="$(shasum -a 256 "$tmp/alist-stub.tar.gz" | awk '{print $1}')"

# Checksum mismatch must fail.
if ALIST_ARCHIVE="$tmp/alist-stub.tar.gz" ALIST_SHA256="0000" \
   "$repo_root/scripts/build-addon.sh" v9.9.9 arm "$tmp/dist-bad" >/dev/null 2>&1; then
  fail "build-addon.sh accepted a wrong SHA-256"
fi

# Missing checksum without ALLOW_UNVERIFIED must fail.
if ALIST_ARCHIVE="$tmp/alist-stub.tar.gz" \
   "$repo_root/scripts/build-addon.sh" v9.9.9 arm "$tmp/dist-bad" >/dev/null 2>&1; then
  fail "build-addon.sh built without a checksum"
fi

for arch in arm aarch64 x86_64; do
  ALIST_ARCHIVE="$tmp/alist-stub.tar.gz" ALIST_SHA256="$sha256" \
    "$repo_root/scripts/build-addon.sh" 9.9.9 "$arch" "$tmp/dist" >/dev/null
  zip="$tmp/dist/$arch/service.alist-9.9.9.zip"
  [[ -f "$zip" ]] || fail "missing $zip"

  listing="$(unzip -Z1 "$zip")"
  for entry in service.alist/addon.xml service.alist/default.py service.alist/bin/alist \
               service.alist/bin/alist.start service.alist/system.d/service.alist.service \
               service.alist/resources/settings.xml service.alist/resources/icon.png \
               service.alist/settings-default.xml service.alist/licenses/AList-AGPL-3.0.txt \
               service.alist/licenses/GPL-2.0.txt service.alist/changelog.txt \
               service.alist/resources/language/resource.language.zh_cn/strings.po; do
    grep -qx "$entry" <<<"$listing" || fail "$zip lacks $entry"
  done
  grep -q 'addon.xml.in' <<<"$listing" && fail "$zip leaked addon.xml.in"
  grep -q 'DS_Store' <<<"$listing" && fail "$zip leaked .DS_Store"
  grep -qE '__pycache__|\.pyc$' <<<"$listing" && fail "$zip leaked Python bytecode"

  # Every entry must be under the add-on id folder.
  grep -vq '^service.alist/' <<<"$listing" && fail "$zip has entries outside service.alist/"

  mkdir -p "$tmp/x-$arch"
  unzip -q "$zip" -d "$tmp/x-$arch"
  [[ -x "$tmp/x-$arch/service.alist/bin/alist" ]] || fail "bin/alist not executable ($arch)"
  [[ -x "$tmp/x-$arch/service.alist/bin/alist.start" ]] || fail "bin/alist.start not executable ($arch)"

  addon_xml="$tmp/x-$arch/service.alist/addon.xml"
  xmllint --noout "$addon_xml"
  [[ "$(xmllint --xpath 'string(/addon/@id)' "$addon_xml")" == "service.alist" ]] || fail "addon id"
  [[ "$(xmllint --xpath 'string(/addon/@version)' "$addon_xml")" == "9.9.9" ]] || fail "addon version"
  grep -q '@' "$addon_xml" && fail "unrendered placeholder in $addon_xml"
  grep -q 'AList 9.9.9' "$addon_xml" || fail "news not rendered"

  defaults="$tmp/x-$arch/service.alist/settings-default.xml"
  xmllint --noout "$defaults"
  [[ "$(xmllint --xpath 'string(/settings/setting[@id="ALIST_HTTP_PORT"])' "$defaults")" == "5244" ]] || fail "settings-default port"
  [[ "$(xmllint --xpath 'string(/settings/setting[@id="ALIST_ADMIN_PASSWORD"])' "$defaults")" == "coreelec" ]] || fail "settings-default password"
  xmllint --xpath '/settings/setting[@id="info_url"]' "$defaults" >/dev/null 2>&1 && fail "action settings leaked into settings-default"
done

# Repository site.
"$repo_root/scripts/build-repository.sh" "$tmp/dist" "$tmp/site" "https://example.test/repo" >/dev/null
for arch in arm aarch64 x86_64; do
  site="$tmp/site/$arch"
  [[ -f "$site/addons.xml.gz" && -f "$site/addons.xml.gz.md5" ]] || fail "missing addons.xml.gz for $arch"
  [[ -f "$site/service.alist/service.alist-9.9.9.zip" ]] || fail "service zip not in site ($arch)"
  [[ -f "$site/service.alist/service.alist-9.9.9.zip.md5" ]] || fail "service zip md5 missing ($arch)"
  [[ -f "$site/service.alist/resources/icon.png" ]] || fail "icon missing in site ($arch)"
  [[ -f "$site/repository.alist.$arch/resources/icon.png" ]] || fail "repository icon missing in site ($arch)"
  repo_zip="$(ls "$site/repository.alist.$arch/"repository.alist.$arch-*.zip)"
  [[ -f "$repo_zip" ]] || fail "repository zip missing ($arch)"
  [[ -f "$tmp/dist/$arch/$(basename "$repo_zip")" ]] || fail "repository zip not copied to dist ($arch)"

  addons_xml="$(gunzip -c "$site/addons.xml.gz")"
  grep -q 'id="service.alist"' <<<"$addons_xml" || fail "addons.xml lacks service.alist ($arch)"
  grep -q "id=\"repository.alist.$arch\"" <<<"$addons_xml" || fail "addons.xml lacks repository ($arch)"

  repo_addon_xml="$(unzip -p "$repo_zip" "repository.alist.$arch/addon.xml")"
  grep -q "https://example.test/repo/$arch/addons.xml.gz" <<<"$repo_addon_xml" || fail "repository info url ($arch)"
  grep -q "<datadir zip=\"true\">https://example.test/repo/$arch</datadir>" <<<"$repo_addon_xml" || fail "repository datadir ($arch)"
  grep -q '@' <<<"$repo_addon_xml" && fail "unrendered placeholder in repository addon.xml ($arch)"

  # md5 file must match the served file (Kodi compares them).
  expected="$(awk '{print $1}' "$site/addons.xml.gz.md5")"
  actual="$(python3 -c 'import hashlib,sys;print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$site/addons.xml.gz")"
  [[ "$expected" == "$actual" ]] || fail "addons.xml.gz.md5 mismatch ($arch)"
done
[[ -f "$tmp/site/index.html" && -f "$tmp/site/.nojekyll" ]] || fail "site index/.nojekyll missing"
grep -q 'repository.alist.arm-' "$tmp/site/index.html" || fail "index.html lacks arm repository link"

echo "Build pipeline test passed."
