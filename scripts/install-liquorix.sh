#!/bin/bash

set -euo pipefail

log() {
    case "$1" in
    INFO)
        echo -e "\033[32m[INFO ] $2\033[0m" # green
	;;
    ERROR)
        echo -e "\033[31m[ERROR] $2\033[0m" # red
	;;
    esac
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
export NEEDRESTART_SUSPEND="*" # suspend needrestart or it will restart services automatically

dist="$(grep '^ID_LIKE=' /etc/os-release | sed 's/ID_LIKE=//' | head -1)"
if [ -z "$dist" ]; then
    dist="$(grep '^ID=' /etc/os-release | sed 's/ID=//' | head -1)"
fi

log INFO "Distribution is $dist"

case "$dist" in
*ubuntu*)
    add-apt-repository ppa:damentz/liquorix && apt-get update

    echo ""
    log INFO "Liquorix PPA repository added successfully"
    echo ""

    apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

    echo ""
    log INFO "Liquorix kernel installed successfully"
    echo ""
    ;;
*debian*)
    # Install debian repo
    mkdir -p /etc/apt/{sources.list.d,trusted.gpg.d}
    curl -o /etc/apt/trusted.gpg.d/liquorix-keyring.gpg \
        'https://liquorix.net/liquorix-keyring.gpg'
    echo ""
    log INFO "Liquorix keyring added to /etc/apt/trusted.gpg.d/liquorix-keyring.gpg"
    echo ""

    apt-get install apt-transport-https lsb-release -y

    repo_file="/etc/apt/sources.list.d/liquorix.list"
    repo_code="$(lsb_release -cs)"
    echo "deb [arch=amd64] https://liquorix.net/debian $repo_code main"      > $repo_file
    echo "deb-src [arch=amd64] https://liquorix.net/debian $repo_code main" >> $repo_file

    apt-get update -y

    echo ""
    log INFO "Liquorix repository added successfully to $repo_file"
    echo ""

    apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

    echo ""
    log INFO "Liquorix kernel installed successfully"
    echo ""
    ;;
*arch*)

    gpg_key='9AE4078033F8024D'
    sudo pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys $gpg_key
    sudo pacman-key --lsign-key $gpg_key
    log INFO "Liquorix keyring added to pacman-key"

    repo_file='/etc/pacman.conf'
    if ! grep -q 'liquorix.net/archlinux' /etc/pacman.conf; then
        echo -e '\n[liquorix]\nServer = https://liquorix.net/archlinux/$repo/$arch' |\
            sudo tee -a $repo_file
        log INFO "Liquorix repository added successfully to $repo_file"
    else
        log INFO "Liquorix repo already configured in $repo_file, skipped add step"
    fi

    if ! pacman -Q | grep -q linux-lqx; then
        sudo pacman -Sy linux-lqx linux-lqx-headers
        log INFO "Liquorix kernel installed successfully"
    else
        log INFO "Liquorix kernel already installed"
    fi
    ;;
*)
    log ERROR "This distribution is not supported at this time"
    exit 1
    ;;
esac
