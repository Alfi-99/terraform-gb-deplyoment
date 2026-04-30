# =============================================================================
# RDS - Relational Database Service
# MySQL database untuk data aplikasi
# Free tier: db.t3.micro, 20GB storage, single AZ
# =============================================================================

# DB Subnet Group - Mendefinisikan subnet mana yang boleh digunakan RDS
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  description = "Subnet group untuk RDS ${local.name_prefix}"

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

# DB Parameter Group - Konfigurasi database engine
resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-db-params"
  family      = "mysql8.0"
  description = "Parameter group untuk ${local.name_prefix}"

  # Konfigurasi performa MySQL
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "100" # Free tier t3.micro: max 100 connections
  }

  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
  }

  tags = {
    Name = "${local.name_prefix}-db-params"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-db"

  # Engine
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage (Free tier: 20GB)
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage # Disable autoscaling untuk free tier
  storage_type          = "gp2"
  storage_encrypted     = true

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup (Free tier: 0 untuk disable, atau 1-7 hari)
  backup_retention_period = 1 # 1 hari backup retention
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"

  # Multi-AZ: false untuk free tier
  multi_az = false

  # Monitoring
  monitoring_interval = 0 # 0 = disable enhanced monitoring (gratis)

  # Performance Insights (Matikan untuk menghindari masalah kompatibilitas t3.micro)
  performance_insights_enabled          = false

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Deletion protection: false untuk development
  deletion_protection = false

  # Final snapshot: skip untuk development
  skip_final_snapshot       = true
  final_snapshot_identifier = "${local.name_prefix}-final-snapshot"

  tags = {
    Name = "${local.name_prefix}-db"
  }
}

# CloudWatch Alarm untuk RDS CPU tinggi
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU RDS di atas 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name = "${local.name_prefix}-rds-cpu-alarm"
  }
}

# CloudWatch Alarm untuk RDS Storage rendah
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${local.name_prefix}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB tersisa
  alarm_description   = "Storage RDS tersisa kurang dari 2GB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name = "${local.name_prefix}-rds-storage-alarm"
  }
}
