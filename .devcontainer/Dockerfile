FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:18

# Install required tools for compiling C and building rootfs
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    gcc \
    make \
    build-essential \
    sudo

# Allow the node user to run sudo without a password
# (This is required because basic-container needs sudo to run clone() with namespaces)
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
    && chmod 0440 /etc/sudoers.d/node
