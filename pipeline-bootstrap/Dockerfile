FROM jenkins/jenkins:lts

USER root

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install OpenTofu
RUN curl -L -o tofu.tar.gz https://github.com/opentofu/opentofu/releases/download/v1.10.4/tofu_1.10.4_linux_amd64.tar.gz && \
    tar -xzf tofu.tar.gz && \
    mv tofu /usr/local/bin/ && \
    rm tofu.tar.gz

# Install Helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    rm get_helm.sh

# Install basic tools
RUN apt-get update && apt-get install -y git curl wget && rm -rf /var/lib/apt/lists/*

USER jenkins

# Install Jenkins plugins for Kubernetes deployment
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
