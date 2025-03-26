FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

### Gitpod user ###
# '-l': see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
    # Remove `use_pty` option and enable passwordless sudo for users in the 'sudo' group
    && sed -i.bkp -e '/Defaults\tuse_pty/d' -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers \
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

ARG KBN_DIR

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
ENV NVM_DIR=${HOME}/nvm
ENV NVM_VERSION=v0.39.1
ENV OPENSSL_PATH=${HOME}/openssl
# Only specific versions are FIPS certified.
ENV OPENSSL_VERSION='3.0.8'

RUN sudo apt-get update && sudo apt-get install -y curl git zsh locales docker.io perl make gcc xvfb git-lfs

# configure git-lfs
RUN git lfs install --system --skip-repo

RUN sudo locale-gen en_US.UTF-8

# Oh My Zsh setup
RUN if [ ! -d "$HOME/.oh-my-zsh" ]; then \
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; \
  fi && \
  ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom} && \
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then \
  git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions; \
  fi && \
  sed -i 's/plugins=(git)/plugins=(git ssh-agent npm docker zsh-autosuggestions)/' /home/gitpod/.zshrc


# FIPS setup
# https://github.com/openssl/openssl/blob/openssl-3.0/README-FIPS.md
# https://www.openssl.org/docs/man3.0/man7/fips_module.html
WORKDIR ${HOME}

RUN set -e ; \
  mkdir -p "${OPENSSL_PATH}"; \
  curl --retry 8 -S -L -O "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" ; \
  curl --retry 8 -S -L -O "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.sha256" ; \
  echo "$(cat openssl-${OPENSSL_VERSION}.tar.gz.sha256) openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c ; \
  tar -zxf "openssl-${OPENSSL_VERSION}.tar.gz" ; \
  rm -rf openssl-${OPENSSL_VERSION}.tar* ; \
  cd "${OPENSSL_PATH}-${OPENSSL_VERSION}" ; \
  ./Configure --prefix="${OPENSSL_PATH}" --openssldir="${OPENSSL_PATH}/ssl" --libdir="${OPENSSL_PATH}/lib" shared -Wl,-rpath,${OPENSSL_PATH}/lib enable-fips; \
  make -j $(nproc) > /dev/null ; \
  make install > /dev/null ; \
  rm -rf  "${OPENSSL_PATH}-${OPENSSL_VERSION}" ; \
  chown -R 33333:33333 "${OPENSSL_PATH}";

WORKDIR ${KBN_DIR}

# Node and NVM setup
COPY .node-version /tmp/

# Mac will have permissions issues if Node and NVM are installed as root
USER gitpod

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

USER root

# Reload the env everytime a new shell is opened incase the .env file changed.
RUN echo "source ${KBN_DIR}/.devcontainer/scripts/env.sh" >> ${HOME}/.bashrc && \
  echo "source ${KBN_DIR}/.devcontainer/scripts/env.sh" >> ${HOME}/.zshrc

