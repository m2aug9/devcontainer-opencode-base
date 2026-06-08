FROM ubuntu:26.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    unzip \
    zsh \
    wget \
    tzdata \
    zlib1g-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.14
RUN wget -q "https://www.python.org/ftp/python/3.14.5/Python-3.14.5.tgz" \
    && tar xvf Python-3.14.5.tgz \
    && cd Python-3.14.5 \
    && ./configure --enable-optimizations --without-ensurepip --enable-loadable-sqlite-extensions \
    && make -j 8 \
    && make install \
    && cd ../ && rm -rf Python-3.14.5 \
    && ln -s /usr/local/bin/python3 /usr/local/bin/python \
    && python -m ensurepip --default-pip

# Install AWS CLI v2
RUN case "$(dpkg --print-architecture)" in \
        amd64) awscli_arch="x86_64" ;; \
        arm64) awscli_arch="aarch64" ;; \
        *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${awscli_arch}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Install GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt-get update \
	&& apt-get install gh -y

# Install Node.js 24.x
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs

WORKDIR /workspaces/FinancialAnalysis

# Install OpenAI Codex, Anthropic Claude Code, and OpenCode AI CLI tools
# RUN npm install -g aws-cdk @openai/codex @anthropic-ai/claude-code opencode-ai
# Install AWS CDK, OpenCode AI CLI tools
RUN npm install -g aws-cdk opencode-ai

USER ubuntu

CMD ["sleep", "infinity"]
