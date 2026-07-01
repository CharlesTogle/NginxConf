# 001: Port 443 Ownership

**Date**: 2026-07-01

## Decision

Port 443 belongs to whoever handles full TLS termination.

- **Tailscale Funnel** owns port 443 when it handles TLS (as it does now).
- **nginx** only gets port 443 if it manages HTTPS end-to-end with its own certificates (e.g. self-signed or real CA).

## Rationale

Only one process can bind a given port + IP. The process that terminates TLS should own port 443 because:

- Tailscale owns the `*.ts.net` domain — Funnel is the natural TLS terminator for those hostnames.
- Funnel listens on 443 and forwards decrypted HTTP to nginx on 80, so nginx never needs raw TLS.
- nginx on the Tailscale IP only needs port 80 for plain HTTP routing.

## When nginx should get 443

If nginx serves a domain where Tailscale does not handle TLS (e.g. a real public domain with Let's Encrypt, or `*.home` with a private CA), then nginx should own port 443. In that case, Tailscale Funnel must be stopped or reconfigured to not bind 443.
