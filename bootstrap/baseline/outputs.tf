output "metallb_pool_ip" {
  value       = var.lb_ip
  description = "Single IP advertised by MetalLB L2."
}
