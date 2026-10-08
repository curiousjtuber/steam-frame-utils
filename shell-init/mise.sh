# steam-frame-utils: mise activated, so the tools it manages are on PATH: rust,
# which a Rust package in pkgbuilds/ needs for cargo, and whatever else `mise use -g`
# added. Skipped when mise isn't installed or is activated already (mise sets
# MISE_SHELL). Sourced from the block setup.sh --mise puts at the end of
# ~/.bashrc and ~/.zshrc. Details:
# https://github.com/curiousjtuber/steam-frame-utils#mise
if [[ -x $HOME/.local/bin/mise && -z ${MISE_SHELL:-} ]]; then
    if [[ -n ${ZSH_VERSION:-} ]]; then
        eval "$("$HOME/.local/bin/mise" activate zsh)"
    else
        eval "$("$HOME/.local/bin/mise" activate bash)"
    fi
fi
