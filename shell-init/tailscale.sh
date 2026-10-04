# steam-frame-utils: the tailscale CLI, run on the host from a distrobox too.
# Sourced from the block setup.sh --tailscale puts at the end of ~/.bashrc and
# ~/.zshrc. Details:
# https://github.com/curiousjtuber/steam-frame-utils#the-tailscale-alias
if [[ -n $CONTAINER_ID || -e /run/.containerenv ]]; then
    alias tailscale='distrobox-host-exec /home/.tailscale/bin/tailscale'
else
    alias tailscale=/home/.tailscale/bin/tailscale
fi
