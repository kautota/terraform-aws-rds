variable "access_key" {}
variable "secret_key" {}
variable "db_name_input" {}

provider "aws" {
  region = local.region
  access_key = var.access_key
  secret_key = var.secret_key
}

data "aws_availability_zones" "available" {}

locals {
  name   = var.db_name_input
  region = "us-west-2"
  password = "UberSecretPassword"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-rds"
  }

  engine                = "postgres"
  engine_version        = "14"
  family                = "postgres14" # DB parameter group
  major_engine_version  = "14"         # DB option group
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  port                  = 5432
}

################################################################################
# Master DB
################################################################################

module "master" {
  source = "../../"

  identifier = "${local.name}-master"

  engine               = local.engine
  engine_version       = local.engine_version
  family               = local.family
  major_engine_version = local.major_engine_version
  instance_class       = local.instance_class

  allocated_storage     = local.allocated_storage
  max_allocated_storage = local.max_allocated_storage

  db_name  = "kttestdb"
  username = "kttestdbuser"
  port     = local.port

  password = "UberSecretPassword"
  # Not supported with replicas
  manage_master_user_password = false

  iam_database_authentication_enabled = true

  multi_az               = true
  # db_subnet_group_name   = module.vpc.database_subnet_group_name
  create_db_subnet_group = true
  subnet_ids             = module.vpc.public_subnets
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Backups are required in order to create a replica
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  storage_encrypted       = false

  publicly_accessible = true

  tags = local.tags
}

# create db user for master db
provider "postgresql" {
  host     = module.master.db_instance_address
  port     = 5432
  database = "postgres"
  username = module.master.db_instance_username
  password = local.password

  superuser = false
}

resource "postgresql_role" "admin" {
  name            = "admin"
  login           = true
  password        = "mypass"
  create_database = true
  roles = [
    "rds_superuser", "rds_iam"
  ]
}

resource "postgresql_role" "iam_admin" {
  name            = "iam_admin"
  login           = true
  password        = "mypass"
  create_database = true
  roles = [
    "rds_superuser", "rds_iam"
  ]
}

################################################################################
# Replica DB
################################################################################

/*
module "replica" {
  source = "../../"

  identifier = "${local.name}-replica"

  # Source database. For cross-region use db_instance_arn
  replicate_source_db = module.master.db_instance_identifier

  engine               = local.engine
  engine_version       = local.engine_version
  family               = local.family
  major_engine_version = local.major_engine_version
  instance_class       = local.instance_class

  allocated_storage     = local.allocated_storage
  max_allocated_storage = local.max_allocated_storage

  port = local.port

  multi_az               = false
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window              = "Tue:00:00-Tue:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  storage_encrypted       = false

  tags = local.tags
}
*/

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  create_database_subnet_group = true

  tags = local.tags
}

/*module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs = local.azs
  private_subnets = ["subnet-0aeaaaa3d1bc347de", "subnet-0323b90cdd162f97f", "subnet-078ce2dc5657057e6", "subnet-0da1c4acbe1b52b6a", "subnet-0ff8274862b82e8d8", "subnet-00e619fc5812b2342"]

}*/

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "Replica PostgreSQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = local.tags
}
