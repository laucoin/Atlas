provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}

provider "helm" {
  kubernetes {
    config_path = pathexpand(var.kubeconfig_path)
  }
}

provider "kubectl" {
  config_path      = pathexpand(var.kubeconfig_path)
  load_config_file = true
}
