######### VPC Variables ################

variable "vpc_cidr" {
  description = "AWS VPC cidr block"
  type        = string
  default     = "10.100.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones for VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_public_subnets" {
  description = "AWS VPC public subnets"
  type        = list(string)
  default     = ["10.100.200.0/24", "10.100.201.0/24"]
}

variable "vpc_public_subnets_names" {
  description = "AWS VPC public subnets names"
  type        = list(string)
  default     = ["pub1a", "pub1b"]
}

variable "vpc_private_subnets" {
  description = "AWS VPC private subnets"
  type        = list(string)
  default     = ["10.100.100.0/24", "10.100.101.0/24", "10.100.160.0/24", "10.100.161.0/24", "10.100.1.0/24"]
}

variable "vpc_private_subnets_names" {
  description = "AWS VPC private subnets names"
  type        = list(string)
  default     = ["int1a", "int1b", "kub1a", "kub1b", "inf1a"]
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}


############  EC2 Variables  ###############

variable "ec2_attributes" {
  description = "Attributes for ec2 instances"
  type        = map(any)
  default = {
    ldap = {
      name          = "ldap"
      private_ip    = "10.100.1.10"
      instance_type = "t3.medium"
      monitoring    = true
      user_data     = "./user-data/ldap-user-data.sh"
      ami           = "ami-033d3612433d4049b"
    }
    foreman = {
      name          = "foreman"
      private_ip    = "10.100.1.11"
      instance_type = "t3.medium"
      monitoring    = true
      user_data     = "./user-data/foreman-user-data.sh"
      ami           = "ami-033d3612433d4049b"
    }
    troubleshoot = {
      name          = "troubleshoot"
      private_ip    = "10.100.200.50"
      instance_type = "t3.medium"
      monitoring    = true
      user_data     = "./user-data/troubleshoot-user-data.sh"
      ami           = "ami-033d3612433d4049b"
    }
  }
}

#########   Tags and Names Variables  ##########

variable "project_name" {
  description = "Name of the project."
  type        = string
  default     = "semicloud"
}

variable "environment" {
  description = "Name of the environment."
  type        = string
  default     = "dev"
}


variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default     = {}
}

variable "nat_tags" {
  description = "Tags to apply to resources created by VPC module"
  type        = map(string)
  default = {
    Name = " Main NAT"
  }
}

variable "igw_tags" {
  description = "Tags to apply to resources created by VPC module"
  type        = map(string)
  default = {
    Name = "Internet Gateway"
  }
}