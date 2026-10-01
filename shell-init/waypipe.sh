# steam-frame-utils: waypipe from a Game Mode terminal, which has no
# WAYLAND_DISPLAY. Inserted by setup.sh --waypipe from shell-init/waypipe.sh;
# edit that and re-run it. Details:
# https://github.com/curiousjtuber/steam-frame-utils#the-waypipe-function
function waypipe {
    if [[ -z $WAYLAND_DISPLAY && -n $GAMESCOPE_WAYLAND_DISPLAY ]]; then
        WAYLAND_DISPLAY=$GAMESCOPE_WAYLAND_DISPLAY command waypipe "$@"
    else
        command waypipe "$@"
    fi
}
