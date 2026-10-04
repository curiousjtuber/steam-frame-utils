# The checkout is this file's grandparent, taken from its own path: BASH_SOURCE in bash, %x in zsh.
if [[ -n ${BASH_SOURCE[0]:-} ]]; then _sfu_bin=${BASH_SOURCE[0]}; else _sfu_bin=${(%):-%x}; fi
_sfu_bin=${_sfu_bin%/*}
_sfu_bin=${_sfu_bin%/*}/bin
case :$PATH: in
    *:"$_sfu_bin":*) ;;
    *) export PATH="$_sfu_bin:$PATH" ;;
esac
unset _sfu_bin
