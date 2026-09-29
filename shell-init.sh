# Steam Frame host init, for bash and zsh. Source it at the end of ~/.bashrc and ~/.zshrc:
#
#   source ~/steam-frame-utils/shell-init.sh
#
# The bare host and its distroboxes share this home, so the same file runs in both, and zsh
# itself is a distrobox export. Checks for "am I on the host" belong here, not in ~/.bashrc.

# install-tailscale.sh puts tailscale under /home/.tailscale. Inside a container, neither that
# path nor the daemon's socket in the host's /run is visible, so the CLI has to run on the host.
if [[ -n $CONTAINER_ID || -e /run/.containerenv ]]; then
    alias tailscale='distrobox-host-exec /home/.tailscale/bin/tailscale'
else
    alias tailscale=/home/.tailscale/bin/tailscale
fi

# Game Mode is an X11 session: gamescope names its Wayland socket only in
# GAMESCOPE_WAYLAND_DISPLAY, so a waypipe client started from a terminal there finds no
# compositor. Fill it in for waypipe alone -- exporting it would move every Qt/GTK app the
# terminal starts off Xwayland.
function waypipe {
    if [[ -z $WAYLAND_DISPLAY && -n $GAMESCOPE_WAYLAND_DISPLAY ]]; then
        WAYLAND_DISPLAY=$GAMESCOPE_WAYLAND_DISPLAY command waypipe "$@"
    else
        command waypipe "$@"
    fi
}
