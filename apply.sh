#!/usr/bin/env bash
set -euo pipefail

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
CONFIG_DIR="$(dirname "$0")/sites-available"

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "No sites-available directory found next to this script."
    exit 1
fi

for conf in "$CONFIG_DIR"/*.conf; do
    name="$(basename "$conf")"

    echo "Installing $name ..."
    sudo cp "$conf" "$NGINX_AVAILABLE/$name"

    if [[ ! -L "$NGINX_ENABLED/$name" ]]; then
        sudo ln -s "$NGINX_AVAILABLE/$name" "$NGINX_ENABLED/$name"
        echo "  -> enabled"
    else
        echo "  -> already enabled"
    fi
done

echo "Testing nginx config ..."
sudo nginx -t

echo "Reloading nginx ..."
sudo systemctl reload nginx

echo "Done."
