function waypipe {
    if [[ -z $WAYLAND_DISPLAY && -n $GAMESCOPE_WAYLAND_DISPLAY ]]; then
        WAYLAND_DISPLAY=$GAMESCOPE_WAYLAND_DISPLAY command waypipe "$@"
    else
        command waypipe "$@"
    fi
}
