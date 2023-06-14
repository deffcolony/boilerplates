terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.6.1"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"  # Path to your kubeconfig file

  // (Optional) Override the default cluster context
  // context = "your-cluster-context"

  // (Optional) Specify the version of the Kubernetes API to use
  // version = "1.21.0"

  // (Optional) Configure authentication for your cluster
  // load_config_file = false
  // host            = "https://your-cluster-api-server"
  // username        = "your-username"
  // password        = "your-password"
  // client_certificate     = file("path/to/client-certificate")
  // client_key             = file("path/to/client-key")
  // cluster_ca_certificate = file("path/to/cluster-ca-certificate")

  // (Optional) Configure timeouts for various operations
  // read_timeout_seconds     = 30
  // write_timeout_seconds    = 30
  // delete_timeout_seconds   = 60
  // apply_timeout_seconds    = 60
  // upgrade_timeout_seconds  = 300
  // rollback_timeout_seconds = 300
}
