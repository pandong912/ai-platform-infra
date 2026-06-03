locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "opentofu"
    Component   = "temporal-deps"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = var.network_state_key
    region = var.state_region
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = var.eks_state_key
    region = var.state_region
  }
}

resource "aws_db_subnet_group" "temporal" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_db_parameter_group" "temporal" {
  name   = "${var.db_identifier}-pg"
  family = "postgres16"

  # PoC convenience: Temporal chart can be configured for TLS later.
  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "temporal_postgres" {
  name        = "${var.db_identifier}-postgres"
  description = "Allow PostgreSQL access to Temporal RDS from EKS nodes"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks_nodes" {
  security_group_id            = aws_security_group.temporal_postgres.id
  referenced_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS worker nodes"
}

resource "aws_vpc_security_group_egress_rule" "postgres_all_egress" {
  security_group_id = aws_security_group.temporal_postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress"
}

resource "aws_db_instance" "temporal" {
  identifier = var.db_identifier

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = max(var.db_allocated_storage, 100)
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.temporal.name
  parameter_group_name   = aws_db_parameter_group.temporal.name
  vpc_security_group_ids = [aws_security_group.temporal_postgres.id]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true
  copy_tags_to_snapshot   = true
  backup_retention_period = 1
}
