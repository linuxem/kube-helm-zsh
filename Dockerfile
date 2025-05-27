# Use a lightweight base image
FROM alpine:3.21.3
# Set maintainer label (optional)
LABEL maintainer="eli.maor@gmail.com"

ARG USERNAME=devops
ARG USER_UID=1002
ARG USER_GID=1002
# Create a non-root user with specified UID and GID
RUN addgroup -g ${USER_GID} ${USERNAME} && \
    adduser -D -u ${USER_UID} -G ${USERNAME} -s /bin/zsh ${USERNAME}
# Define versions for Helm and kubectl (you can update these as needed)
ARG KUBECTL_VERSION=v1.32.0
# Define the Helm version and architecture
ARG HELM_VERSION=v3.18.0
ARG TARGETARCH

# Install dependencies including zsh and git (for Oh My Zsh)
# and tools for Oh My Zsh installation (curl or wget)
RUN apk add --no-cache \
    curl \
    ca-certificates \
    bash \
    git \
    openssh-client \
    zsh \
    wget \
    sudo \
    coreutils \
    util-linux \
    util-linux # Provides 'chsh' if needed, though we'll set user shell differently

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH:-amd64}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl
RUN  set -x; cd "$(mktemp -d)" && \
    curl -fsSLO "https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubectx_v0.9.5_linux_x86_64.tar.gz" && \
    tar zxvf kubectx_v0.9.5_linux_x86_64.tar.gz && mv kubectx /usr/local/bin/kubectx 

# Install Helm
RUN curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH:-amd64}.tar.gz" && \
    tar -zxvf helm-${HELM_VERSION}-linux-${TARGETARCH:-amd64}.tar.gz && \
    mv linux-${TARGETARCH:-amd64}/helm /usr/local/bin/helm && \
    rm -rf helm-${HELM_VERSION}-linux-${TARGETARCH:-amd64}.tar.gz linux-${TARGETARCH:-amd64}

USER ${USERNAME}
# Install Oh My Zsh non-interactively
# Running as devops, so Oh My Zsh will be installed for devops user
# If you create a non-root user, you'd run this under that user's context
RUN sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
# The '|| true' is to prevent build failure if install.sh tries to switch to zsh and exits non-zero

# Optionally, set a default Oh My Zsh theme (e.g., "agnoster")
# RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' //home/devops/.zshrc
# Note: Some themes might require powerline fonts to be installed in your local terminal, not just in the container.
# Set the default shell for the user to zsh
RUN chsh -s /bin/zsh ${USERNAME} || true     
# Configure zsh and Oh My Zsh for root user
# This ensures that when root logs in (or CMD is zsh), .zshrc is sourced.
# For Oh My Zsh, the installer usually modifies .zshrc.
# We'll also ensure .zshrc is present for devops.
RUN echo 'export ZSH="/home/devops/.oh-my-zsh"' >> /home/devops/.zshrc && \
    echo 'source $ZSH/oh-my-zsh.sh' >> /home/devops/.zshrc

# Configure .zshrc for the non-root user
RUN { \
        echo "# Path to your Oh My Zsh installation."; \
        echo "export ZSH=\"/home/${USERNAME}/.oh-my-zsh\""; \
        echo "# Set name of the theme to load."; \
        echo "ZSH_THEME=\"robbyrussell\""; \
        echo "# Standard plugins can be found in \$ZSH/plugins/"; \
        echo "plugins=(git kubectl helm)"; \
        echo "source \$ZSH/oh-my-zsh.sh"; \
        echo "# User configuration"; \
        echo "export PATH=\"/usr/local/bin:\$PATH\""; \
        echo ""; \
        echo "# Custom Aliases"; \
        echo "alias c=\"clear\""; \
        echo "alias k=\"kubectl\""; \
        echo "alias kgp=\"kubectl get pods\""; \
        echo "alias kgn=\"kubectl get nodes\""; \
        echo "alias hls=\"helm list\""; \
    } > /home/${USERNAME}/.zshrc

# Ensure the .zshrc file is readable by the user
RUN chmod 644 /home/devops/.zshrc

# Install Krew
RUN ( set -x; cd "$(mktemp -d)" && \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v0.4.5/krew-linux_amd64.tar.gz" && \
    tar zxvf krew-linux_amd64.tar.gz && \
    KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" && \
    "$KREW" install krew )

# Set the default shell to zsh for subsequent RUN, CMD, ENTRYPOINT
SHELL ["/bin/zsh", "-c"]

# # Verify installations (now using zsh)
# RUN kubectl version --client && \
#     helm version && \
#     echo "Oh My Zsh should be installed. Current shell: $0"
RUN mkdir $HOME/.kube
# Set a working directory (optional)
WORKDIR /home/devops

# Default command to start zsh
CMD ["zsh"]