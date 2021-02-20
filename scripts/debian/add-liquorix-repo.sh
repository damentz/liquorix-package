#!/bin/bash

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "[ERROR] You must run this script as root!"
    exit 0
fi

codename="$(
    find /etc/apt -maxdepth 1 -type f -name '*.list' | \
    xargs grep -E '^deb' | awk '{print $3}' | \
    grep -Eo '^[a-z]+' | sort | uniq -c | sort -n | tail -n1 | \
    grep -Eo '[a-z]+$'
)" 

if [[ -z "$codename" ]]; then
    echo "[ERROR] Unable to detect system code name!"
    exit 0
fi

mkdir -p /etc/apt/{sources.list.d,trusted.gpg.d}

apt-get install curl -y
curl -o /etc/apt/trusted.gpg.d/liquorix-keyring.gpg \
    'https://liquorix.net/liquorix-keyring.gpg'

echo ""
echo "[INFO ] Liquorix keyring added to /etc/apt/trusted.gpg.d/liquorix-keyring.gpg"
echo ""

apt-get install apt-transport-https -y

repo_file="/etc/apt/sources.list.d/liquorix.list"
echo "deb http://liquorix.net/debian $codename main
deb-src http://liquorix.net/debian $codename main

# Mirrors:
#
# Unit193 - France
# deb http://mirror.unit193.net/liquorix $codename main
# deb-src http://mirror.unit193.net/liquorix $codename main" > \
    $repo_file

apt-get update

echo ""
echo "[INFO ] Liquorix repository added successfully to $repo_file"
echo ""
echo "[INFO ] You can now install Liquorix with:"
echo "[INFO ] sudo apt-get install linux-image-liquorix-amd64 linux-headers-liquorix-amd64"
