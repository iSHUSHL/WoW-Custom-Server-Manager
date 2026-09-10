#!/bin/bash
set -Eeuo pipefail
ACTION="${1:-install}"
export NONINTERACTIVE=1

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to manage the MySQL runtime. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  fi
}

ensure_brew
case "$ACTION" in
  install)
    echo "Installing MySQL 8.4 runtime..."
    if brew list --versions mysql@8.4 >/dev/null 2>&1; then
      echo "MySQL 8.4 is already installed."
    else
      brew install mysql@8.4
    fi
    echo "MySQL 8.4 runtime ready. Control Center will manage isolated instances itself."
    ;;
  repair)
    echo "Repairing MySQL 8.4 runtime..."
    if brew list --versions mysql@8.4 >/dev/null 2>&1; then
      brew reinstall mysql@8.4
    else
      brew install mysql@8.4
    fi
    echo "MySQL 8.4 runtime repaired. Existing Control Center realm data was not deleted."
    ;;
  uninstall)
    echo "Uninstalling Homebrew MySQL 8.4 runtime..."
    if brew list --versions mysql@8.4 >/dev/null 2>&1; then
      brew uninstall mysql@8.4
    else
      echo "MySQL 8.4 runtime is already absent."
    fi
    echo "MySQL 8.4 runtime removed. Control Center realm data directories were kept."
    ;;
  *) echo "Unknown action: $ACTION" >&2; exit 2;;
esac
