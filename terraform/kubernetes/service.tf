resource "kubernetes_service" "your-service" {
  metadata {
    name      = "your-service"
    namespace = "your-namespace"
  }

  spec {
    selector = {
      app = "your-app-selector"
    }

    port {
      name       = "http"
      protocol   = "TCP"
      port       = 80
      targetPort = 8080
    }

    type = "ClusterIP"
  }
}