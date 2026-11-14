FROM ubuntu:24.04

ARG KUBECTL_VERSION=v1.35.5
ARG HELM_VERSION=v3.22.1
ARG TERRAFORM_VERSION=1.14.3
ARG K6_VERSION=1.5.0
ARG K3D_VERSION=v5.9.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    unzip \
    bash \
    docker.io \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# kubectl
RUN curl -fsSLo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# Helm
RUN curl -fsSL \
    "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    | tar -xz \
    && install linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64

# Terraform
RUN curl -fsSLo /tmp/terraform.zip \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip

# k6
RUN curl -fsSLo /tmp/k6.tar.gz \
    "https://github.com/grafana/k6/releases/download/v${K6_VERSION}/k6-v${K6_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/k6.tar.gz -C /tmp \
    && install /tmp/k6-v${K6_VERSION}-linux-amd64/k6 /usr/local/bin/k6 \
    && rm -rf /tmp/k6*

# k3d
RUN curl -fsSLo /usr/local/bin/k3d \
    "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64" \
    && chmod +x /usr/local/bin/k3d

WORKDIR /workspace

CMD ["sleep", "infinity"]
