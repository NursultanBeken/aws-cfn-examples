provider "aws" {
  region  = "us-west-2"
}
##################
# Create the VPC #
##################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.18.0"

  name = "codelab-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["us-west-2a", "us-west-2b"]

  # For the bastion host
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  # For the NAT gateways
  public_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

  # For the RDS Instance
  database_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # Ensure the private gateways can talk to the internet for SSM
  enable_nat_gateway = true

  # Allow private DNS
  enable_dns_hostnames = true
  enable_dns_support   = true
}

#######################
# Create the database #
#######################

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "2.5.0"

  # Put the DB in a private subnet of the VPC created above
  vpc_security_group_ids = [module.db_security_group.this_security_group_id]
  create_db_subnet_group = false
  db_subnet_group_name   = module.vpc.database_subnet_group

  # Make it postgres just as an example
  identifier     = "codelab-db"
  name           = "codelab_db"
  engine         = "postgres"
  engine_version = "10.6"
  username       = "codelab_user"
  password       = "codelab_password"
  port           = 5432

  # Disable stuff we don't care about
  create_db_option_group    = false
  create_db_parameter_group = false

  # Other random required variables that we don't care about in this codelab
  allocated_storage  = 5 # GB
  instance_class     = "db.t2.small"
  maintenance_window = "Tue:00:00-Tue:03:00"
  backup_window      = "03:00-06:00"
}

module "db_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.1.0"

  name   = "codelab-db-sg"
  vpc_id = module.vpc.vpc_id

  # Allow all incoming SSL traffic from the VPC
  ingress_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  ingress_rules       = ["postgresql-tcp"]

  # Allow all outgoing HTTP and HTTPS traffic for updates
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["http-80-tcp", "https-443-tcp"]
}

###############################
# Create the bastion instance #
###############################

module "bastion_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.1.0"

  name   = "codelab-bastion-sg"
  vpc_id = module.vpc.vpc_id

  # Allow all outgoing HTTP and HTTPS traffic, as well as communication to db
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["http-80-tcp", "https-443-tcp", "postgresql-tcp"]
}

module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.12.0"

  # Ubuntu 18.04 LTS AMI
  ami                    = "ami-090717c950a5c34d3"
  name                   = "codelab-bastion"
  instance_type          = "t2.small"
  vpc_security_group_ids = [module.bastion_security_group.this_security_group_id]
  subnet_ids             = module.vpc.private_subnets
  iam_instance_profile   = module.instance_profile_role.this_iam_instance_profile_name

  # Install dependencies
  user_data = <<USER_DATA
#!/bin/bash
sudo apt-get update
sudo apt-get -y install ec2-instance-connect
  USER_DATA
}

module instance_profile_role {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 3.0"

  role_name               = "codelab-role"
  create_role             = true
  create_instance_profile = true
  role_requires_mfa       = false

  trusted_role_services = ["ec2.amazonaws.com"]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceConnect",
  ]
}

###########
# Outputs #
###########

output "instance_id" {
  value = module.bastion.id[0]
}

output "az" {
  value = module.bastion.availability_zone[0]
}

output "rds_endpoint" {
  value = module.db.this_db_instance_endpoint
}