FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV MISE_DATA_DIR=/mise
ENV MISE_CONFIG_DIR=/mise
ENV MISE_CACHE_DIR=/mise/cache
ENV MISE_INSTALL_PATH=/usr/local/bin/mise
ENV PATH=/mise/shims:/mise/bin:$PATH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    unzip \
    zsh \
    && rm -rf /var/lib/apt/lists/*

RUN case "$(dpkg --print-architecture)" in \
        amd64) awscli_arch="x86_64" ;; \
        arm64) awscli_arch="aarch64" ;; \
        *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${awscli_arch}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

RUN mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt-get update \
	&& apt-get install gh -y

RUN install -d -o ubuntu -g ubuntu /mise /workspaces /home/ubuntu/.config /home/ubuntu/.history

RUN curl -fsSL https://mise.run | sh

COPY --chown=ubuntu:ubuntu mise.toml /workspaces/mise.toml
COPY --chown=ubuntu:ubuntu pyproject.toml /workspaces/pyproject.toml
COPY --chown=ubuntu:ubuntu requirements.txt /workspaces/requirements.txt

WORKDIR /workspaces

RUN mise trust /workspaces/mise.toml \
    && mise install --yes \
    && npm install -g aws-cdk opencode-ai \
    && chown -R ubuntu:ubuntu /mise

USER ubuntu

CMD ["sleep", "infinity"]
