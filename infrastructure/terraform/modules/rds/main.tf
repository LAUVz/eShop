# RDS PostgreSQL

resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_db_instance" "main" {
  identifier             = "${var.name_prefix}-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  storage_encrypted      = false  # Disabled for initial deployment

  db_name  = "eshop"
  username = "eshop_admin"
  password = var.rds_master_password

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  skip_final_snapshot = true

  tags = var.tags
}
