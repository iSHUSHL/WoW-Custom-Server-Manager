#!/bin/bash
set -Eeuo pipefail
export NONINTERACTIVE=1
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required for one-time runtime provisioning. Installing it now..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
fi
brew update
brew install cmake boost openssl@3 readline icu4c git pkgconf mysql@8.4 ninja p7zip
printf '\nRuntime dependencies ready. MySQL is NOT installed as a login service; WoW Control Center starts its own isolated instance.\n'
