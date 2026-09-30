# waypipe from a Game Mode terminal, for bash and zsh. setup.sh inserts this file into ~/.bashrc
# and ~/.zshrc, between steam-frame-utils markers; edit it here and re-run setup.sh.
#
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
