if [[ -n $CONTAINER_ID || -e /run/.containerenv ]]; then
    alias tailscale='distrobox-host-exec /home/.tailscale/bin/tailscale'
else
    alias tailscale=/home/.tailscale/bin/tailscale
fi
