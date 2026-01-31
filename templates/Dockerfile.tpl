FROM {{BASE_IMAGE}}

# Install base packages for dev container
RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y \
        tmux \
        screen \
        socat \
        telnet \
        netcat-openbsd \
        xauth \
        xclip \
        xsel \
        xdg-utils \
        tzdata \
        curl \
        git \
        jq \
{{EXTRA_PACKAGES_LINE}}    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
