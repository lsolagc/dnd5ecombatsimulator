FROM mcr.microsoft.com/devcontainers/ruby:1-3.4-bullseye

# Install Rails
RUN su vscode -c "gem install rails webdrivers"
RUN su vscode -c "/usr/local/rvm/bin/rvm fix-permissions"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains 
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

# Instala dependências de compilação e bibliotecas comuns no desenvolvimento Ruby
# Remove a lista apt do yarn: sua chave GPG expirou e quebra o apt-get update (yarn já vem instalado na imagem)
RUN rm -f /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y \
    git curl build-essential libssl-dev libreadline-dev zlib1g-dev \
    libsqlite3-dev sqlite3 libffi-dev libyaml-dev \
    postgresql-client libpq-dev libvips jq \
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

# Instala uma versão de Node via nvm: a imagem só traz o gerenciador, sem nenhuma versão
# instalada. NVM_SYMLINK_CURRENT=true (já setado na imagem) mantém current/bin no PATH
# global, então os passos seguintes não precisam mais dar `source` no nvm.sh.
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts"

# Claude Code CLI, disponível no terminal integrado dentro do container
RUN su vscode -c "npm install -g @anthropic-ai/claude-code"

# Caveman (token savings): CLI + hooks + recovery tool no perfil do vscode
RUN su vscode -c "npm install -g @caveman-ai/cli"
RUN su vscode -c "caveman tools hooks install claude && caveman tools mcp install claude --server caveman"

# Ponytail (plugin do Claude Code)
RUN su vscode -c "claude plugin marketplace add DietrichGebert/ponytail && claude plugin install ponytail@ponytail -y"

# rtk (proxy CLI de economia de token)
RUN su vscode -c "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
ENV PATH="/home/vscode/.local/bin:${PATH}"

# rtk não tem instalador de hook próprio (rtk hook claude só processa stdin) — registra
# manualmente o PreToolUse/Bash no settings.json, mesclando com o que caveman/ponytail já escreveram
RUN su vscode -c '\
    mkdir -p ~/.claude && \
    [ -s ~/.claude/settings.json ] || echo "{}" > ~/.claude/settings.json && \
    jq ".hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":\"rtk hook claude\"}]}])" ~/.claude/settings.json > /tmp/settings.json && \
    mv /tmp/settings.json ~/.claude/settings.json \
    '
