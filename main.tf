provider "aws" {
  region = var.aws_region
}

locals {

  name_suffix = "${var.project_name}.${var.environment}"
  required_tags = {
    project     = var.project_name,
    environment = var.environment
  }
  tags = merge(var.resource_tags, local.required_tags)

}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "vpc-${local.name_suffix}"
  cidr = var.vpc_cidr

  azs                  = var.vpc_azs
  public_subnets       = var.vpc_public_subnets
  public_subnet_names  = var.vpc_public_subnets_names
  private_subnets      = var.vpc_private_subnets
  private_subnet_names = var.vpc_private_subnets_names

  map_public_ip_on_launch          = true
  enable_nat_gateway               = true
  single_nat_gateway               = true
  one_nat_gateway_per_az           = false
  enable_dns_hostnames             = false
  enable_dhcp_options              = true
  dhcp_options_domain_name         = "semicloud.dev"
  dhcp_options_domain_name_servers = ["127.0.0.1", var.ec2_attributes.ldap.private_ip, "10.100.0.2"]
  nat_gateway_tags                 = var.nat_tags
  igw_tags                         = var.igw_tags


  tags = local.tags
}


module "security_group" {
  source      = "./modules/security_groups"
  name_suffix = local.name_suffix
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags

}

module "aws_key_pair" {
  source      = "./modules/keys"
  name_suffix = local.name_suffix
}

resource "aws_instance" "ldap" {

  instance_type          = var.ec2_attributes.ldap.instance_type
  key_name               = module.aws_key_pair.key_pair_name
  monitoring             = var.ec2_attributes.ldap.monitoring
  vpc_security_group_ids = ["${module.security_group.sg_id}"]
  subnet_id              = module.vpc.private_subnets[4]
  private_ip             = var.ec2_attributes.ldap.private_ip
  user_data              = file(var.ec2_attributes.ldap.user_data)
  ami                    = var.ec2_attributes.ldap.ami

  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp3"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = "${var.ec2_attributes.ldap.name}.${local.name_suffix}"
  }
}

resource "aws_instance" "foreman" {

  instance_type          = var.ec2_attributes.ldap.instance_type
  key_name               = module.aws_key_pair.key_pair_name
  monitoring             = var.ec2_attributes.ldap.monitoring
  vpc_security_group_ids = ["${module.security_group.sg_id}"]
  subnet_id              = module.vpc.private_subnets[4]
  private_ip             = var.ec2_attributes.foreman.private_ip
  user_data              = templatefile(var.ec2_attributes.foreman.user_data, { secgroup = "${module.security_group.sg_id}", subnet = "${module.vpc.public_subnets[0]}" })
  ami                    = var.ec2_attributes.ldap.ami

  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp3"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = "${var.ec2_attributes.foreman.name}.${local.name_suffix}"
  }
}

resource "aws_instance" "troubleshoot" {

  instance_type          = var.ec2_attributes.troubleshoot.instance_type
  key_name               = module.aws_key_pair.key_pair_name
  monitoring             = var.ec2_attributes.troubleshoot.monitoring
  vpc_security_group_ids = ["${module.security_group.sg_id}"]
  subnet_id              = module.vpc.public_subnets[0]
  private_ip             = var.ec2_attributes.troubleshoot.private_ip
  user_data              = file(var.ec2_attributes.troubleshoot.user_data)
  ami                    = var.ec2_attributes.troubleshoot.ami

  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp3"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = "${var.ec2_attributes.troubleshoot.name}.${local.name_suffix}"
  }
}