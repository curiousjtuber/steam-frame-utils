# steam-frame-utils: waypipe from a Game Mode terminal, which has no
# WAYLAND_DISPLAY. Sourced from the block setup.sh --waypipe puts at the end of
# ~/.bashrc and ~/.zshrc. Details:
# https://github.com/curiousjtuber/steam-frame-utils#the-waypipe-function
function waypipe {
    if [[ -z $WAYLAND_DISPLAY && -n $GAMESCOPE_WAYLAND_DISPLAY ]]; then
        WAYLAND_DISPLAY=$GAMESCOPE_WAYLAND_DISPLAY command waypipe "$@"
    else
        command waypipe "$@"
    fi
}
