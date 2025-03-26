FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:git-core/ppa -y

RUN apt-get update && apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  file \
  git \
  gnome-keyring \
  iproute2 \
  libfuse2 \
  libgconf-2-4 \
  libgdk-pixbuf2.0-0 \
  libgl1 \
  libgtk-3.0 \
  libsecret-1-dev \
  libkrb5-dev \
  libssl-dev \
  libx11-dev \
  libx11-xcb-dev \
  libxkbfile-dev \
  locales \
  lsb-release \
  lsof \
  sudo \
  wget \
  xvfb \
  tzdata \
  unzip \
  jq

### Gitpod user ###
# '-l': see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
  # passwordless sudo for users in the 'sudo' group
  && sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers \
  # To emulate the workspace-session behavior within dazzle build env
  && mkdir /workspace && chown -hR gitpod:gitpod /workspace

ENV HOME=/home/gitpod
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo "PS1='\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\$(__git_ps1 \" (%s)\") $ '" ; } >> .bashrc

### Gitpod user (2) ###
USER gitpod
# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Gitpod: success" && \
  # create .bashrc.d folder and source it in the bashrc
  mkdir -p /home/gitpod/.bashrc.d && \
  (echo; echo "for i in \$(ls -A \$HOME/.bashrc.d/); do source \$HOME/.bashrc.d/\$i; done"; echo) >> /home/gitpod/.bashrc && \
  # create a completions dir for gitpod user
  mkdir -p /home/gitpod/.local/share/bash-completion/completions

ENV NVM_DIR=${HOME}/nvm
ENV NVM_VERSION=v0.39.1

# Node and NVM setup
COPY .node-version /tmp/

RUN mkdir -p $NVM_DIR && \
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash && \
  . "$NVM_DIR/nvm.sh" && \
  NODE_VERSION=$(cat /tmp/.node-version) && \
  nvm install ${NODE_VERSION} && \
  nvm use ${NODE_VERSION} && \
  nvm alias default ${NODE_VERSION} && \
  npm install -g yarn && \
  echo "source $NVM_DIR/nvm.sh" >> ${HOME}/.bashrc && \
  echo "source $NVM_DIR/nvm.sh" >> ${HOME}/.zshrc  && \
  chown -R 33333:33333 "${HOME}/.npm"

# Custom PATH additions
ENV PATH=$HOME/.local/bin:/usr/games:$PATH

RUN cd /home/gitpod && \
  mkdir custom_node && \
  wget https://unofficial-builds.nodejs.org/download/release/v18.16.1/node-v18.16.1-linux-x64-glibc-217.tar.gz && \
  tar -xzf node-v18.16.1-linux-x64-glibc-217.tar.gz  -C custom_node --strip-components 1

ENV GP_VSCODE_NODE=/home/gitpod/custom_node/bin/node

