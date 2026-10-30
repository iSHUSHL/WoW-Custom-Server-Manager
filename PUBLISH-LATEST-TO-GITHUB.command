#!/bin/bash
# WoW Server Control Center 1.6.46 - publish source snapshot to GitHub
# Uses YOUR Mac's existing GitHub authentication. Does not ask for tokens.
set -Eeuo pipefail

REPO="iSHUSHL/WoW-Custom-Server-Manager"
REMOTE="https://github.com/${REPO}.git"
BRANCH="main"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$HOME/Downloads/WoWCC-GitHub-Publish-$STAMP"

fail() {
  echo ""
  echo "ERROR: $*" >&2
  echo "Nothing was force-pushed."
  echo "Publish working copy (if created): $WORK_DIR"
  exit 1
}
trap 'echo "Publish failed at line $LINENO" >&2' ERR

echo "WoWCC 1.6.46 - publish current source snapshot"
echo "Repository: https://github.com/$REPO"
echo "Source: $SOURCE_DIR"
echo
command -v git >/dev/null 2>&1 || fail "git is not installed. Run xcode-select --install."
command -v rsync >/dev/null 2>&1 || fail "rsync is not installed."
[[ -f "$SOURCE_DIR/Package.swift" && -f "$SOURCE_DIR/BUILD-WoWCC.command" && \
   -f "$SOURCE_DIR/Sources/WoWServerControlCenter/ServerModel.swift" ]] || \
  fail "Run this .command from the extracted WoWCC ZIP root, not by itself."

# Never copy source into repo before cloning the actual default branch:
# this preserves .github workflows, git history and any unrelated repo files.
echo "Cloning latest '$BRANCH'..."
mkdir -p "$WORK_DIR"
if ! git clone --branch "$BRANCH" --depth 1 "$REMOTE" "$WORK_DIR/repository"; then
  fail "Cannot clone repository. Authenticate git with GitHub (gh auth login, or Git Credential Manager)."
fi
DEST="$WORK_DIR/repository"

# Copy the real project source, not temporary runtime data, compiled bytecode,
# or an old historical ZIP accidentally bundled in prior releases.
echo "Copying complete latest WoWCC source snapshot..."
rsync -a \
  --exclude='.git' \
  --exclude='.DS_Store' \
  --exclude='__MACOSX' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='*.zip' \
  --exclude='build/' \
  --exclude='.build/' \
  --exclude='.swiftpm/' \
  --exclude='runtime/' \
  --exclude='data/' \
  --exclude='*.sqlite' \
  --exclude='*.db' \
  "$SOURCE_DIR/" "$DEST/"

# Keep shell scripts executable in Git as well as in the ZIP.
find "$DEST" -path "$DEST/.git" -prune -o \( -name '*.command' -o -name '*.sh' \) -type f -exec chmod 755 {} +

cd "$DEST"
git add --all
if git diff --cached --quiet; then
  echo "GitHub already matches this source snapshot. Nothing to commit."
  echo "Repository: https://github.com/$REPO"
  exit 0
fi

echo
echo "Files changed in the latest build:"
git diff --cached --stat
echo

git config user.name >/dev/null 2>&1 || fail "Git user.name is missing. Configure with: git config --global user.name 'Your Name'"
git config user.email >/dev/null 2>&1 || fail "Git user.email is missing. Configure with: git config --global user.email 'you@example.com'"

git commit -m "Update WoWCC to 1.6.46 with WotLK transmog collection"

echo "Pushing to $REPO/$BRANCH (no force push)..."
if git push origin "HEAD:$BRANCH"; then
  echo "SUCCESS: Latest WoWCC 1.6.46 source uploaded to GitHub."
  echo "https://github.com/$REPO"
else
  echo "Push rejected or GitHub authentication failed. The committed source is safe at:"
  echo "$DEST"
  echo "Authenticate with 'gh auth login' (or your Git credential manager), then run:"
  echo "cd '$DEST' && git push origin HEAD:$BRANCH"
  exit 2
fi
