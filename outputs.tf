output "vpc_name" {
  description = "Name of the created VPC"
  value       = module.vpc.name
}

output "vpc_id" {
  description = "vpc id for child modules"
  value       = module.vpc.vpc_id
}

output "tags" {
  value = local.tags
}

output "name_suffix" {
  description = "Name suffix for child modules"
  value       = local.name_suffix
}

# output "ldap_public_ip" {
#   description = "LDAP Public IP"
#   value       = aws_instance.ldap.public_ip
# }

# output "foreman_public_ip" {
#   description = "foreman Public IP"
#   value       = aws_instance.foreman.public_ip
# }

output "troubleshoot_public_ip" {
  description = "troubleshoot Public IP"
  value       = aws_instance.troubleshoot.public_ip
}