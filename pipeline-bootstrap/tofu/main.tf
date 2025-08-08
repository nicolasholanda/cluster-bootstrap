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
