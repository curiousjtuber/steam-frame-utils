# steam-frame-utils: terminals in the Frametop desktop. Keeps mise on its own
# dirs; frametop-xdg off|on switches this shell's XDG dirs. Must stay above
# mise activate. Inserted by setup.sh from shell-init/frametop.sh; edit that
# and re-run it. Details:
# https://github.com/curiousjtuber/steam-frame-utils#frametop-terminals
if [[ ${XDG_CONFIG_HOME:-} == "$HOME/.config/frametop" ]]; then
    export MISE_CONFIG_DIR=$HOME/.config/mise
    export MISE_STATE_DIR=$HOME/.local/state/mise
    export FRAMETOP_XDG_CONFIG_HOME=$XDG_CONFIG_HOME
    export FRAMETOP_XDG_STATE_HOME=$XDG_STATE_HOME
fi

if [[ -n ${FRAMETOP_XDG_CONFIG_HOME:-} ]]; then
    function frametop-xdg {
        case ${1:-} in
            off) unset XDG_CONFIG_HOME XDG_STATE_HOME ;;
            on)
                export XDG_CONFIG_HOME=$FRAMETOP_XDG_CONFIG_HOME
                export XDG_STATE_HOME=$FRAMETOP_XDG_STATE_HOME
                ;;
            '') ;;
            *) echo "usage: frametop-xdg [off|on]" >&2; return 2 ;;
        esac
        echo "XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-(unset: ~/.config)}"
        echo "XDG_STATE_HOME=${XDG_STATE_HOME:-(unset: ~/.local/state)}"
    }
fi
