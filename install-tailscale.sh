#!/usr/bin/env bash
# Install or update Tailscale on a Steam Frame (arm64, immutable SteamOS).
#
# Usage:  sudo bash ~/install-tailscale.sh [--trust-tailnet]
#
# Everything lives where SteamOS updates won't wipe it:
#   /home/.tailscale/bin     tailscale + tailscaled (root-owned, on the persistent home partition)
#   /home/.tailscale/state   login/node state
#   /etc/systemd/system/tailscaled.service
#       kept across updates by the default /usr/lib/rauc/atomic-update-keep.conf
#       (it keeps /etc/systemd/system/*.service and *.wants/**)
#
# --trust-tailnet  puts tailscale0 in firewalld's "trusted" zone (all tailnet traffic allowed;
#                  rely on Tailscale ACLs) and adds that zone file to the update keep list.
#                  Without it, only SSH is reachable over the tailnet (default "public" zone).
#
# Re-running updates the binaries and restarts the daemon; login state is kept.
#
# Uninstall:
#   sudo systemctl disable --now tailscaled
#   sudo rm /etc/systemd/system/tailscaled.service && sudo systemctl daemon-reload
#   sudo rm -rf /home/.tailscale
#   # if --trust-tailnet was used:
#   sudo firewall-cmd --permanent --zone=trusted --remove-interface=tailscale0 && sudo firewall-cmd --reload
#   sudo rm /etc/atomic-update.conf.d/tailscale-firewall.conf
#   # the `tailscale` alias itself comes from shell-init.sh

set -euo pipefail

PREFIX=/home/.tailscale
BIN=$PREFIX/bin
STATE=$PREFIX/state
UNIT=/etc/systemd/system/tailscaled.service
SOCKET=/run/tailscale/tailscaled.sock
PKGS=https://pkgs.tailscale.com/stable

trust_tailnet=0
for arg in "$@"; do
  case $arg in
    --trust-tailnet) trust_tailnet=1 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg (see --help)" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

[[ $EUID -eq 0 ]] || die "run as root: sudo bash $0"
[[ $(uname -m) == aarch64 ]] || die "expected aarch64, got $(uname -m)"
grep -qx 'ID=steamos' /etc/os-release || die "this script is for SteamOS"
[[ $(findmnt -no FSTYPE -T /home) != "" ]] || die "/home is not mounted"
if findmnt -no OPTIONS -T /home | tr ',' '\n' | grep -qx noexec; then
  die "/home is mounted noexec; binaries can't run from there"
fi
for cmd in curl jq sha256sum tar systemctl; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

step "Finding latest stable arm64 release"
tarball=$(curl -fsSL "$PKGS/?mode=json" | jq -r '.Tarballs.arm64')
[[ -n $tarball && $tarball != null ]] || die "could not determine arm64 tarball from $PKGS/?mode=json"
echo "$tarball"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

step "Downloading and verifying"
curl -fSL --progress-bar "$PKGS/$tarball" -o "$tmp/$tarball"
expected=$(curl -fsSL "$PKGS/$tarball.sha256" | awk '{print $1}')
actual=$(sha256sum "$tmp/$tarball" | awk '{print $1}')
[[ -n $expected && $expected == "$actual" ]] || die "SHA-256 mismatch (expected '$expected', got '$actual')"
echo "sha256 OK: $actual"

tar -xzf "$tmp/$tarball" -C "$tmp" --no-same-owner
src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -name 'tailscale_*' | head -n1)
[[ -x $src/tailscale && -x $src/tailscaled ]] || die "unexpected tarball layout"

step "Installing to $BIN"
old_version=$( [[ -x $BIN/tailscale ]] && "$BIN/tailscale" version 2>/dev/null | head -n1 || echo none)
install -d -o root -g root -m 755 "$PREFIX" "$BIN"
install -d -o root -g root -m 700 "$STATE"
install -o root -g root -m 755 "$src/tailscale" "$src/tailscaled" "$BIN/"
new_version=$("$BIN/tailscale" version | head -n1)
echo "version: $old_version -> $new_version"

step "Writing $UNIT"
cat >"$UNIT" <<EOF
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service
RequiresMountsFor=$PREFIX

[Service]
# /usr/bin/iptables is the legacy backend, but the Frame kernel has no ip_tables module; use nftables.
Environment=TS_DEBUG_FIREWALL_MODE=nftables
ExecStart=$BIN/tailscaled --statedir=$STATE --socket=$SOCKET
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable tailscaled
systemctl restart tailscaled

if [[ $trust_tailnet -eq 1 ]]; then
  step "Trusting tailscale0 in firewalld"
  command -v firewall-cmd >/dev/null || die "firewall-cmd not found"
  firewall-cmd --permanent --zone=trusted --add-interface=tailscale0
  firewall-cmd --reload
  install -d -m 755 /etc/atomic-update.conf.d
  echo '/etc/firewalld/zones/trusted.xml' >/etc/atomic-update.conf.d/tailscale-firewall.conf
fi

user=${SUDO_USER:-}

step "Waiting for tailscaled"
for _ in $(seq 1 20); do
  [[ -S $SOCKET ]] && break
  sleep 0.5
done
[[ -S $SOCKET ]] || die "tailscaled did not start; check: journalctl -u tailscaled -b"

state=$("$BIN/tailscale" status --json 2>/dev/null | jq -r '.BackendState' || echo unknown)
echo "backend state: $state"

echo
if [[ $state == Running ]]; then
  "$BIN/tailscale" status || true
  echo
  echo "Done. Tailscale is up."
else
  echo "Done. Log in with (scan the QR code with your phone):"
  echo "  sudo $BIN/tailscale up --qr --operator=${user:-steamos} --ssh"
fi
[[ $trust_tailnet -eq 1 ]] || echo "(Firewall unchanged: only SSH is reachable over the tailnet. Re-run with --trust-tailnet to allow all.)"
