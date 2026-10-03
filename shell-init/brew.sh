if [[ -x /home/linuxbrew/.linuxbrew/bin/brew && :$PATH: != *:/home/linuxbrew/.linuxbrew/bin:* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
