# A terminal in the Frametop desktop, for bash and zsh. setup.sh inserts this file at the top of
# ~/.bashrc and ~/.zshrc, between steam-frame-utils markers; edit it here and re-run setup.sh.
#
# Frametop's session gives Plasma config and state dirs of its own (~/.config/frametop and
# ~/.local/state/frametop), so its panels and layout never touch the stock desktop's. Every app it
# starts inherits them, this shell included. That's right for KDE tools run from here, which then
# change the Frametop desktop's settings, but command-line tools miss their own config.
if [[ ${XDG_CONFIG_HOME:-} == "$HOME/.config/frametop" ]]; then
    # mise would take ~/.config/mise/config.toml for an untrusted project file. Its own dirs win
    # over the XDG ones. Exported, and ahead of mise activate (hence the top of the rc file),
    # because mise's prompt hook reads the config again before every prompt.
    export MISE_CONFIG_DIR=$HOME/.config/mise MISE_STATE_DIR=$HOME/.local/state/mise
    # For frametop-xdg, here and in shells started from this one.
    export FRAMETOP_XDG_CONFIG_HOME=$XDG_CONFIG_HOME FRAMETOP_XDG_STATE_HOME=$XDG_STATE_HOME
fi

# frametop-xdg off|on: the usual XDG config and state dirs for the rest of this shell session, for
# tools that would otherwise read the Frametop desktop's; on puts the desktop's back. Without an
# argument, it shows which ones are in use.
if [[ -n ${FRAMETOP_XDG_CONFIG_HOME:-} ]]; then
    function frametop-xdg {
        case ${1:-} in
            off) unset XDG_CONFIG_HOME XDG_STATE_HOME ;;
            on) export XDG_CONFIG_HOME=$FRAMETOP_XDG_CONFIG_HOME XDG_STATE_HOME=$FRAMETOP_XDG_STATE_HOME ;;
            '') ;;
            *) echo "usage: frametop-xdg [off|on]" >&2; return 2 ;;
        esac
        echo "XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-(unset: ~/.config)}"
        echo "XDG_STATE_HOME=${XDG_STATE_HOME:-(unset: ~/.local/state)}"
    }
fi
