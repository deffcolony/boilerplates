resource "kubernetes_secret" "your-secret" {
  metadata {
    name      = "your-secret"
    namespace = "your-namespace"
  }

  data = {
    "username" = base64encode("your-username")
    "password" = base64encode("your-password")
  }
}