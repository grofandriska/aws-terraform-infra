output "website_url" {
  value = "http://${module.loadbalance.lb_dns_name}"
}

output "vpc_id" {
  value = module.infra.vpc_id
}