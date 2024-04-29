#!/bin/bash

set -euo pipefail

log() {
    local level=$1
    local message=$2

    echo ""
    case "$level" in
    INFO) printf "\033[32m[INFO ] %s\033[0m\n" "$message" ;;  # green
    WARN) printf "\033[33m[WARN ] %s\033[0m\n" "$message" ;;  # yellow
    ERROR) printf "\033[31m[ERROR] %s\033[0m\n" "$message" ;; # red
    *) printf "[UNKNOWN] %s\n" "$message" ;;
    esac
    echo ""
}

if [ "$(id -u)" -ne 0 ]; then
    log ERROR "You must run this script as root!"
    exit 1
fi

if [ "$(uname -m)" != x86_64 ]; then
    log ERROR "Architecture not supported"
    exit 1
fi

export DEBIAN_FRONTEND="noninteractive" # `curl <URL> | sudo bash` suppresses stdin
export NEEDRESTART_SUSPEND="*"          # suspend needrestart or it will restart services automatically

# Smash all possible distributions into one line
dists="$(
    grep -P '^ID.*=' /etc/os-release | cut -f2 -d= | tr '\n' ' ' |
        tr '[:upper:]' '[:lower:]' | tr -dc '[:lower:] [:space:]'
)"

# Append upstream distributions through package manager landmarks
command -v apt-get &>/dev/null && dists="$dists debian"
command -v pacman &>/dev/null && dists="$dists arch"

# Deduplicate and trim list of discovered distributions
dists=$(echo "$dists" | tr '[:space:]' '\n' | sort | uniq | xargs)

log INFO "Possible distributions: $dists"

case "$dists" in
*arch*)
    gpg_key='9AE4078033F8024D'
    sudo pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys $gpg_key
    sudo pacman-key --lsign-key $gpg_key
    log INFO "Liquorix keyring added to pacman-key"

    repo_file='/etc/pacman.conf'
    if ! grep -q 'liquorix.net/archlinux' /etc/pacman.conf; then
        echo -e '\n[liquorix]\nServer = https://liquorix.net/archlinux/$repo/$arch' |
            sudo tee -a $repo_file
        log INFO "Liquorix repository added successfully to $repo_file"
    else
        log INFO "Liquorix repo already configured in $repo_file, skipped add step"
    fi

    if ! pacman -Q linux-lqx | grep -q linux-lqx; then
        sudo pacman -Sy --noconfirm linux-lqx linux-lqx-headers
        log INFO "Liquorix kernel installed successfully"
    else
        log INFO "Liquorix kernel already installed"
    fi

    grub_cfg='/boot/grub/grub.cfg'
    if [ -f "$grub_cfg" ]; then
        if sudo grub-mkconfig -o "$grub_cfg"; then
            log INFO "GRUB updated successfully"
        else
            log ERROR "GRUB update failed"
        fi
    fi
    ;;
*ubuntu*)
    apt-get update && apt-get install -y --no-install-recommends \
        gpg gpg-agent software-properties-common

    add-apt-repository -y ppa:damentz/liquorix &&
        apt-get update -y

    log INFO "Liquorix PPA repository added successfully"

    apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

    log INFO "Liquorix kernel installed successfully"
    ;;
*debian*)
    apt-get update && apt-get install -y --no-install-recommends \
        curl gpg ca-certificates

    mkdir -p /etc/apt/{sources.list.d,keyrings}
    chmod 0755 /etc/apt/{sources.list.d,keyrings}

    keyring_url='https://liquorix.net/liquorix-keyring.gpg'
    keyring_path='/etc/apt/keyrings/liquorix-keyring.gpg'
    curl "$keyring_url" | gpg --batch --yes --output "$keyring_path" --dearmor
    chmod 0644 "$keyring_path"

    log INFO "Liquorix keyring added to $keyring_path"

    apt-get install apt-transport-https lsb-release -y

    repo_file="/etc/apt/sources.list.d/liquorix.list"
    repo_code="$(
        apt-cache policy | grep o=Debian | grep -Po 'n=\w+' | cut -f2 -d= |
            sort | uniq -c | sort | tail -n1 | awk '{print $2}'
    )"
    repo_line="[arch=amd64 signed-by=$keyring_path] https://liquorix.net/debian $repo_code main"
    echo "deb $repo_line" >$repo_file
    echo "deb-src $repo_line" >>$repo_file

    apt-get update -y

    log INFO "Liquorix repository added successfully to $repo_file"

    apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

    log INFO "Liquorix kernel installed successfully"
    ;;
*)
    log ERROR "This distribution is not supported at this time"
    exit 1
    ;;
esac
