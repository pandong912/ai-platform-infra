locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "opentofu"
    Component   = "nacos-deps"
  }

  nacos_secret_name = "${var.secrets_path_prefix}/nacos"
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

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "random_password" "nacos_auth_token" {
  length  = 64
  special = false
}

resource "random_string" "nacos_identity_key" {
  length  = 24
  special = false
}

resource "random_string" "nacos_identity_value" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "nacos" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_db_parameter_group" "nacos" {
  name   = "${var.db_identifier}-mysql"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
}

resource "aws_security_group" "nacos_mysql" {
  name        = "${var.db_identifier}-mysql"
  description = "Allow MySQL access to Nacos RDS from EKS nodes"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_eks_nodes" {
  security_group_id            = aws_security_group.nacos_mysql.id
  referenced_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL from EKS worker nodes"
}

resource "aws_vpc_security_group_egress_rule" "mysql_all_egress" {
  security_group_id = aws_security_group.nacos_mysql.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress"
}

resource "aws_db_instance" "nacos" {
  identifier = var.db_identifier

  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = max(var.db_allocated_storage, 100)
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.nacos.name
  parameter_group_name   = aws_db_parameter_group.nacos.name
  vpc_security_group_ids = [aws_security_group.nacos_mysql.id]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true
  copy_tags_to_snapshot   = true
  backup_retention_period = 1
}

resource "aws_secretsmanager_secret" "nacos" {
  name        = local.nacos_secret_name
  description = "Nacos dev database and auth settings."
}

resource "aws_secretsmanager_secret_version" "nacos" {
  secret_id = aws_secretsmanager_secret.nacos.id
  secret_string = jsonencode({
    MYSQL_SERVICE_HOST        = aws_db_instance.nacos.address
    MYSQL_SERVICE_PORT        = tostring(aws_db_instance.nacos.port)
    MYSQL_SERVICE_DB_NAME     = aws_db_instance.nacos.db_name
    MYSQL_SERVICE_USER        = aws_db_instance.nacos.username
    MYSQL_SERVICE_PASSWORD    = random_password.db_password.result
    NACOS_AUTH_TOKEN          = random_password.nacos_auth_token.result
    NACOS_AUTH_IDENTITY_KEY   = random_string.nacos_identity_key.result
    NACOS_AUTH_IDENTITY_VALUE = random_string.nacos_identity_value.result
  })
}
