#!/bin/bash
set -Eeuo pipefail

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

log() { printf '[tbc-extractor] %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
trap 'fail "Extractor engine setup failed at line $LINENO while running: $BASH_COMMAND"' ERR

[[ "$(uname -s)" == "Darwin" ]] || fail "Local extractor engine setup is for macOS only."
[[ "$(uname -m)" == "arm64" ]] || {
  log "This Mac is not Apple Silicon. Native CMaNGOS extractors should be used instead."
  exit 0
}

command -v brew >/dev/null 2>&1 || fail "Homebrew is required. Run Install Dependencies first."

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker CLI…"
  brew install docker
fi

if ! command -v colima >/dev/null 2>&1; then
  log "Installing Colima…"
  brew install colima
fi

if docker info >/dev/null 2>&1; then
  log "Docker engine is already available."
  exit 0
fi

log "Starting Colima for local amd64 extractor execution…"

# Prefer Apple's Virtualization.framework + Rosetta when available.
# If Rosetta is not installed or VZ start fails, fall back to normal Colima
# with binfmt/QEMU foreign-architecture emulation.
if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
  if colima start --vm-type=vz --vz-rosetta --cpu 4 --memory 6 --disk 30; then
    :
  else
    log "VZ/Rosetta start failed; retrying with standard Colima emulation."
    colima stop --force >/dev/null 2>&1 || true
    colima start --cpu 4 --memory 6 --disk 30
  fi
else
  log "Rosetta 2 is not installed; using Colima binfmt/QEMU emulation."
  colima start --cpu 4 --memory 6 --disk 30
fi

for _ in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then
    log "READY — local Docker/Colima extractor engine is running."
    exit 0
  fi
  sleep 1
done

fail "Docker engine did not become ready after starting Colima."
