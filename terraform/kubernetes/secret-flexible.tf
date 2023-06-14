resource "kubernetes_secret" "cloudflare_api_key_secret" {
  
    depends_on = [kubernetes_namespace.your-namespace-object]
    
    metadata {
        name      = var.secret_name
        namespace = var.namespace
    }

    data = {
        api-key = base64encode(var.api_key)
    }

    type = "Opaque"
}