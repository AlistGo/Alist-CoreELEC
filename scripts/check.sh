#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026-present AlistGo (https://github.com/AlistGo)

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for script in scripts/*.sh tests/*.sh; do
  bash -n "$script"
done
sh -n addon/service.alist/bin/alist.start

# Syntax-check without writing __pycache__ into the add-on source tree.
python3 - addon/service.alist/default.py scripts/*.py tools/create_repository.py <<'PY'
import ast, sys
for path in sys.argv[1:]:
    with open(path, encoding='utf-8') as handle:
        ast.parse(handle.read(), path)
PY

for xml in addon/service.alist/addon.xml.in addon/service.alist/resources/settings.xml addon/repository.alist/addon.xml.in; do
  xmllint --noout "$xml"
done

if command -v msgfmt >/dev/null; then
  for po in addon/service.alist/resources/language/*/strings.po; do
    msgfmt --check -o /dev/null "$po"
  done
fi

required=(
  LICENSE
  THIRD_PARTY_NOTICES.md
  licenses/AList-AGPL-3.0.txt
  addon/service.alist/addon.xml.in
  addon/service.alist/default.py
  addon/service.alist/changelog.txt
  addon/service.alist/bin/alist.start
  addon/service.alist/system.d/service.alist.service
  addon/service.alist/resources/icon.png
  addon/service.alist/resources/settings.xml
  addon/service.alist/resources/language/resource.language.en_gb/strings.po
  addon/service.alist/resources/language/resource.language.zh_cn/strings.po
  addon/repository.alist/addon.xml.in
  addon/repository.alist/resources/icon.png
  tools/create_repository.py
)
for path in "${required[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing required path: $path" >&2
    exit 1
  fi
done

if [[ ! -x addon/service.alist/bin/alist.start ]]; then
  echo "addon/service.alist/bin/alist.start must be executable" >&2
  exit 1
fi

# Every settings id must be a plain shell identifier: oe_setup_addon evals them.
while read -r id; do
  if [[ ! "$id" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Setting id is not a valid shell identifier: $id" >&2
    exit 1
  fi
done < <(xmllint --xpath '//setting/@id' addon/service.alist/resources/settings.xml | sed -E 's/ *id="([^"]*)"/\1\n/g' | sed '/^$/d')

# Every label/help id referenced by settings.xml must exist in en_gb strings.po.
while read -r sid; do
  if ! grep -q "msgctxt \"#${sid}\"" addon/service.alist/resources/language/resource.language.en_gb/strings.po; then
    echo "String id #${sid} referenced in settings.xml is missing from strings.po" >&2
    exit 1
  fi
done < <(grep -oE '(label|help)="[0-9]+"' addon/service.alist/resources/settings.xml | grep -oE '[0-9]+' | sort -u)

bash tests/test-build-pipeline.sh

echo "Static checks passed."
