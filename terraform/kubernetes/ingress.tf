resource "kubernetes_ingress" "example" {
  metadata {
    name      = "example-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class" : "nginx"
    }
  }

  spec {
    rule {
      host = "example.com"
      http {
        path {
          backend {
            service_name = kubernetes_service.example.service_name
            service_port = kubernetes_service.example.service_port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "example" {
  metadata {
    name      = "example-service"
    namespace = "default"
  }

  spec {
    selector = {
      app = "example-app"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }
  }
}
