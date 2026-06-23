#!/usr/bin/env bash
set -euo pipefail

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
CONFIG_DIR="$(dirname "$0")/sites-available"
BIND_DIR="$(dirname "$0")/bind"
BIND_TARGET_DIR="/etc/bind"

sudo -v

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

if [[ -d "$BIND_DIR" ]]; then
    for bind_conf in named.conf.options named.conf.local db.home; do
        source_file="$BIND_DIR/$bind_conf"

        if [[ ! -f "$source_file" ]]; then
            echo "Missing BIND config: $source_file"
            exit 1
        fi

        echo "Installing $bind_conf ..."
        sudo cp "$source_file" "$BIND_TARGET_DIR/$bind_conf"
    done

    echo "Testing bind config ..."
    sudo named-checkconf
    sudo named-checkzone home "$BIND_TARGET_DIR/db.home"

    echo "Reloading bind9 ..."
    sudo systemctl reload bind9
fi

echo "Done."
