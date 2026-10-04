# steam-frame-utils: this checkout's bin/ on PATH, found from this file's own
# path (BASH_SOURCE in bash, %x in zsh). Sourced from the block setup.sh puts
# at the top of ~/.bashrc and ~/.zshrc, after brew.sh so that bin/ comes first.
# Details: https://github.com/curiousjtuber/steam-frame-utils#shell-init
if [[ -n ${BASH_SOURCE[0]:-} ]]; then _sfu_bin=${BASH_SOURCE[0]}; else _sfu_bin=${(%):-%x}; fi
_sfu_bin=${_sfu_bin%/*}
_sfu_bin=${_sfu_bin%/*}/bin
case :$PATH: in
    *:"$_sfu_bin":*) ;;
    *) export PATH="$_sfu_bin:$PATH" ;;
esac
unset _sfu_bin
