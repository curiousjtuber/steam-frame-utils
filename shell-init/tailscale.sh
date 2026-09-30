# The tailscale CLI, for bash and zsh. setup.sh inserts this file into ~/.bashrc and ~/.zshrc,
# between steam-frame-utils markers; edit it here and re-run setup.sh.
#
# The bare host and its distroboxes share this home, so the block runs in both, and zsh itself is
# a distrobox export. install-tailscale.sh puts tailscale under /home/.tailscale. Inside a
# container, neither that path nor the daemon's socket in the host's /run is visible, so the CLI
# has to run on the host.
if [[ -n $CONTAINER_ID || -e /run/.containerenv ]]; then
    alias tailscale='distrobox-host-exec /home/.tailscale/bin/tailscale'
else
    alias tailscale=/home/.tailscale/bin/tailscale
fi
