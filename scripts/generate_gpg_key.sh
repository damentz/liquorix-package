#!/bin/bash
set -euo pipefail

# Allow user to specify Name and Email, defaulting to liquorix builder defaults
NAME=${1:-"Liquorix Builder"}
EMAIL=${2:-"builder@liquorix.net"}

echo "Generating GPG key for $NAME <$EMAIL>..."

mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

# Generate key non-interactively if it does not already exist
if ! gpg --list-secret-keys "$EMAIL" >/dev/null 2>&1; then
    gpg --batch --passphrase '' --quick-generate-key "$NAME <$EMAIL>" default default never
else
    echo "Key for $EMAIL already exists, skipping generation."
fi

# Extract the key ID
KEY_ID=$(gpg --list-secret-keys --with-colons "$EMAIL" | awk -F: '/^sec:/ {print $5}' | head -n 1)

if [ -z "$KEY_ID" ]; then
    echo "Error: Failed to find the generated key ID."
    exit 1
fi

echo "Generated Key ID: $KEY_ID"

# Add it as the default key only if it's not already set
if ! grep -q "^default-key $KEY_ID" ~/.gnupg/gpg.conf 2>/dev/null; then
    echo "default-key $KEY_ID" >> ~/.gnupg/gpg.conf
fi

echo "Done! The key ($KEY_ID) has been set as your default-key in ~/.gnupg/gpg.conf."
