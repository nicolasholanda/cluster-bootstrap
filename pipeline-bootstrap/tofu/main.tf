resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
  }
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "jenkins" {
  metadata {
    name = "jenkins-robot"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "persistentvolumeclaims", "configmaps", "secrets", "serviceaccounts"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata {
    name = "jenkins-robot"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = kubernetes_service_account.jenkins.metadata[0].namespace
  }
}

resource "kubernetes_secret" "jenkins_kubeconfig" {
  metadata {
    name      = "jenkins-kubeconfig"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }

  data = {
    "config" = file(var.kubeconfig_path)
  }

  type = "Opaque"
}

resource "kubernetes_deployment" "jenkins" {
  metadata {
    name = "jenkins"
    namespace = kubernetes_namespace.infra.metadata[0].name
    labels = {
      app = "jenkins"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "jenkins"
      }
    }
    template {
      metadata {
        labels = {
          app = "jenkins"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.jenkins.metadata[0].name
        init_container {
          name  = "install-tools"
          image = "alpine:latest"
          command = ["/bin/sh"]
          args = ["-c", <<-EOT
            apk add --no-cache curl && \
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
            install -o root -g root -m 0755 kubectl /shared/kubectl && \
            curl -L -o tofu.tar.gz https://github.com/opentofu/opentofu/releases/download/v1.10.4/tofu_1.10.4_linux_amd64.tar.gz && \
            tar -xzf tofu.tar.gz && \
            mv tofu /shared/tofu && \
            curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
            chmod 700 get_helm.sh && \
            HELM_INSTALL_DIR=/shared ./get_helm.sh --no-sudo
          EOT
          ]
          volume_mount {
            name       = "shared-tools"
            mount_path = "/shared"
          }
        }
        container {
          name  = "jenkins"
          image = "jenkins/jenkins:lts"
          image_pull_policy = "Always"
          port {
            container_port = 8080
          }
          security_context {
            run_as_non_root = true
            run_as_user = 1000
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }
          volume_mount {
            name       = "jenkins-home"
            mount_path = "/var/jenkins_home"
          }
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
          volume_mount {
            name       = "kubeconfig"
            mount_path = "/var/jenkins_home/.kube"
            read_only  = true
          }
          volume_mount {
            name       = "shared-tools"
            mount_path = "/usr/local/bin"
            read_only  = true
          }
          env {
            name  = "KUBECONFIG"
            value = "/var/jenkins_home/.kube/config"
          }
          env {
            name  = "PATH"
            value = "/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          }
          liveness_probe {
            http_get {
              path = "/login"
              port = 8080
            }
            initial_delay_seconds = 120
            period_seconds = 30
            timeout_seconds = 10
          }
          readiness_probe {
            http_get {
              path = "/login"
              port = 8080
            }
            initial_delay_seconds = 60
            period_seconds = 10
            timeout_seconds = 5
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
          }
        }
        volume {
          name = "jenkins-home"
          empty_dir {}
        }
        volume {
          name = "tmp"
          empty_dir {}
        }
        volume {
          name = "kubeconfig"
          secret {
            secret_name = kubernetes_secret.jenkins_kubeconfig.metadata[0].name
          }
        }
        volume {
          name = "shared-tools"
          empty_dir {}
        }
        security_context {
          run_as_non_root = true
          run_as_user = 1000
          fs_group = 1000
        }
      }
    }
  }
}

resource "kubernetes_service" "jenkins" {
  metadata {
    name = "jenkins"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }
  spec {
    selector = {
      app = "jenkins"
    }
    port {
      port        = 8080
      target_port = 8080
    }
    type = "ClusterIP"
  }
}
