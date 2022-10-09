#!/bin/bash

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "[ERROR] You must run this script as root!"
    exit 0
fi

case $(uname -m) in
x86_64)
    ARCH=x64  # or AMD64 or Intel64 or whatever
    ;;
*)
    echo "ERROR: Architecture not supported."
    exit
    ;;
esac

dist=$(grep '^ID' /etc/os-release | sed 's/ID=//' | head -1)
if [ "$dist" = "debian" ]; then
    # Install debian repo
    apt-get install lsb-release -y
    mkdir -p /etc/apt/{sources.list.d,trusted.gpg.d}
    curl -o /etc/apt/trusted.gpg.d/liquorix-keyring.gpg \
        'https://liquorix.net/liquorix-keyring.gpg'
    echo ""
    echo "[INFO ] Liquorix keyring added to /etc/apt/trusted.gpg.d/liquorix-keyring.gpg"
    echo ""

    apt-get install apt-transport-https -y

    repo_file="/etc/apt/sources.list.d/liquorix.list"
    repo_code="$(lsb_release -cs)"
    echo "deb https://liquorix.net/debian $repo_code main"      > $repo_file
    echo "deb-src https://liquorix.net/debian $repo_code main" >> $repo_file

    apt-get update -y
    if [ $ARCH = "x64" ]; then
        sudo apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64
    fi

    echo ""
    echo "[INFO] Liquorix repository added successfully to $repo_file"
    echo ""
elif [ "$dist" = "ubuntu" ]; then
    echo "Distribution is $dist"

    sudo add-apt-repository ppa:damentz/liquorix && sudo apt-get update
    if [ $ARCH = "x64" ]; then
        sudo apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64
    fi

    echo ""
    echo "[INFO] Liquorix PPA repository added successfully"
    echo ""
else
    echo "ERROR: This distribution is not supported at this time."
    exit
fi

