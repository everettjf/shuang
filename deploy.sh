#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${ROOT_DIR}/.deploy-gh-pages"
BRANCH="gh-pages"
REMOTE="${REMOTE:-origin}"
DRY_RUN="${DRY_RUN:-0}"
COMMIT_SHA="$(git -C "${ROOT_DIR}" rev-parse --short HEAD)"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %z')"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd git
require_cmd npm
require_cmd rsync

if ! git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must be run inside a git repository." >&2
  exit 1
fi

CURRENT_BRANCH="$(git -C "${ROOT_DIR}" branch --show-current)"

echo "Building site..."
npm --prefix "${ROOT_DIR}" run build

echo "Preparing ${BRANCH} worktree..."
if git -C "${ROOT_DIR}" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  git -C "${ROOT_DIR}" worktree remove "${DEPLOY_DIR}" --force >/dev/null 2>&1 || true
  git -C "${ROOT_DIR}" worktree add "${DEPLOY_DIR}" "${BRANCH}"
else
  git -C "${ROOT_DIR}" ls-remote --exit-code --heads "${REMOTE}" "${BRANCH}" >/dev/null 2>&1 || true
  if git -C "${ROOT_DIR}" ls-remote --exit-code --heads "${REMOTE}" "${BRANCH}" >/dev/null 2>&1; then
    git -C "${ROOT_DIR}" fetch "${REMOTE}" "${BRANCH}:${BRANCH}"
    git -C "${ROOT_DIR}" worktree remove "${DEPLOY_DIR}" --force >/dev/null 2>&1 || true
    git -C "${ROOT_DIR}" worktree add "${DEPLOY_DIR}" "${BRANCH}"
  else
    rm -rf "${DEPLOY_DIR}"
    mkdir -p "${DEPLOY_DIR}"
    git -C "${ROOT_DIR}" worktree add --detach "${DEPLOY_DIR}"
    git -C "${DEPLOY_DIR}" checkout --orphan "${BRANCH}"
  fi
fi

cleanup() {
  git -C "${ROOT_DIR}" worktree remove "${DEPLOY_DIR}" --force >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Syncing files..."
find "${DEPLOY_DIR}" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

rsync -a "${ROOT_DIR}/index.html" "${DEPLOY_DIR}/"
rsync -a "${ROOT_DIR}/build" "${DEPLOY_DIR}/"
rsync -a "${ROOT_DIR}/img" "${DEPLOY_DIR}/"
rsync -a "${ROOT_DIR}/assets" "${DEPLOY_DIR}/"
cp "${ROOT_DIR}/LICENSE" "${DEPLOY_DIR}/LICENSE"
touch "${DEPLOY_DIR}/.nojekyll"

git -C "${DEPLOY_DIR}" add --all

if git -C "${DEPLOY_DIR}" diff --cached --quiet; then
  echo "No changes to deploy."
  exit 0
fi

echo "Committing deployment..."
git -C "${DEPLOY_DIR}" commit -m "Deploy ${CURRENT_BRANCH}@${COMMIT_SHA} ${TIMESTAMP}"

if [[ "${DRY_RUN}" == "1" ]]; then
  echo "Dry run enabled; skipping push."
  exit 0
fi

echo "Pushing to ${REMOTE}/${BRANCH}..."
git -C "${DEPLOY_DIR}" push "${REMOTE}" "${BRANCH}"

echo "Deployment finished."
