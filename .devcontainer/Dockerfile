FROM mcr.microsoft.com/devcontainers/ruby:1-3.4-bullseye

# Install Rails
RUN su vscode -c "gem install rails webdrivers"
RUN su vscode -c "/usr/local/rvm/bin/rvm fix-permissions"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains 
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

# Instala dependências de compilação e bibliotecas comuns no desenvolvimento Ruby
RUN apt-get update && apt-get install -y \
    git curl build-essential libssl-dev libreadline-dev zlib1g-dev \
    libsqlite3-dev sqlite3 libffi-dev libyaml-dev \
    postgresql-client libpq-dev libvips \
    && rm -rf /var/lib/apt/lists/*

# Usa rbenv já instalado no sistema, se presente
ENV RBENV_ROOT=/usr/local/share/rbenv
# Instala o plugin ruby-build para permitir o uso do comando `rbenv install`
RUN git clone https://github.com/rbenv/ruby-build.git ${RBENV_ROOT}/plugins/ruby-build && \
    ${RBENV_ROOT}/plugins/ruby-build/install.sh
ENV PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"

# Usa versão do Ruby declarada no .ruby-version
COPY .ruby-version /tmp/.ruby-version
RUN rbenv install -s $(cat /tmp/.ruby-version) && \
    rbenv global $(cat /tmp/.ruby-version) && \
    rbenv rehash

# Instala bundler
RUN gem install bundler

# [Optional] Uncomment this line to install additional gems.
# RUN su vscode -c "gem install <your-gem-names-here>"

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1
