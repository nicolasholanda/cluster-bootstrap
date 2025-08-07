FROM jenkins/jenkins:lts

USER root

# Install Python and pipx for Checkov and other tools
RUN apt-get update && \
    apt-get install -y python3 python3-pip curl unzip && \
    pip install --user pipx && pipx ensurepath && pipx install checkov

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install OpenTofu
RUN curl -L -o tofu.tar.gz "https://github.com/opentofu/opentofu/releases/download/v1.10.4/tofu_1.10.4_linux_amd64.tar.gz" && \
    tar -xzf tofu.tar.gz && \
    mv tofu /usr/local/bin/ && \
    chmod +x /usr/local/bin/tofu && \
    rm tofu.tar.gz

# Install Jenkins plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
