#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] You must run this script as root!"
    exit 1
fi

if [ $(uname -m) != x86_64 ]; then
    echo "[ERROR] Architecture not supported"
    exit 1
fi

case $(grep '^ID' /etc/os-release | sed 's/ID=//' | head -1) in
debian)
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
    echo "deb [arch=amd64] https://liquorix.net/debian $repo_code main"      > $repo_file
    echo "deb-src [arch=amd64] https://liquorix.net/debian $repo_code main" >> $repo_file

    apt-get update -y
    apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

    echo ""
    echo "[INFO ] Liquorix repository added successfully to $repo_file"
    echo ""
    ;;
ubuntu)
    echo "Distribution is $dist"

    add-apt-repository ppa:damentz/liquorix && apt-get update
    apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

    echo ""
    echo "[INFO ] Liquorix PPA repository added successfully"
    echo ""
    ;;
*)
    echo "[ERROR] This distribution is not supported at this time"
    exit 1
    ;;
esac
