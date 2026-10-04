# steam-frame-utils: Homebrew on PATH, on the host; a distrobox doesn't see
# /home/linuxbrew. Skipped when it is on PATH already. Sourced from the block
# setup.sh --brew puts at the top of ~/.bashrc and ~/.zshrc. Details:
# https://github.com/curiousjtuber/steam-frame-utils#homebrew
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew && :$PATH: != *:/home/linuxbrew/.linuxbrew/bin:* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
