#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_ROOT="${REPO_ROOT}/skills"
DEST_ROOT="${CODEX_HOME:-$HOME/.codex}/skills"

if [ ! -d "${SRC_ROOT}" ]; then
  echo "skills source directory not found: ${SRC_ROOT}" >&2
  exit 1
fi

mkdir -p "${DEST_ROOT}"

install_one() {
  local name="$1"
  local src="${SRC_ROOT}/${name}"
  local dst="${DEST_ROOT}/${name}"

  if [ ! -d "${src}" ]; then
    echo "skip: ${name} (not found in ${SRC_ROOT})" >&2
    return 0
  fi

  rm -rf "${dst}"
  mkdir -p "${dst}"
  cp -R "${src}/." "${dst}/"
  echo "installed: ${name} -> ${dst}"
}

if [ "$#" -eq 0 ]; then
  # Install all local repo skills
  while IFS= read -r skill_dir; do
    install_one "$(basename "${skill_dir}")"
  done < <(find "${SRC_ROOT}" -mindepth 1 -maxdepth 1 -type d | sort)
else
  for skill in "$@"; do
    install_one "${skill}"
  done
fi

echo "done"
