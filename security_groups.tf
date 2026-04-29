# =============================================================================
# SECURITY GROUPS - Firewall rules untuk setiap layer
# =============================================================================

# ---------------------------------------------------------------------------
# Security Group: Application Load Balancer
# Menerima traffic dari internet (HTTP/HTTPS)
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group untuk Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Izinkan HTTP dari mana saja
  ingress {
    description = "HTTP dari internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Izinkan HTTPS dari mana saja
  ingress {
    description = "HTTPS dari internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Izinkan semua outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# ---------------------------------------------------------------------------
# Security Group: Elastic Beanstalk (EC2 instances)
# Hanya menerima traffic dari ALB
# ---------------------------------------------------------------------------
resource "aws_security_group" "elastic_beanstalk" {
  name        = "${local.name_prefix}-eb-sg"
  description = "Security group untuk Elastic Beanstalk instances"
  vpc_id      = aws_vpc.main.id

  # Hanya terima traffic dari ALB pada port 8080 (Node.js default EB)
  ingress {
    description     = "HTTP dari ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "App port dari ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Izinkan semua outbound (untuk download dependencies, dll)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-eb-sg"
  }
}

# ---------------------------------------------------------------------------
# Security Group: RDS Database
# Hanya menerima koneksi dari Elastic Beanstalk dan Lambda
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group untuk RDS Database"
  vpc_id      = aws_vpc.main.id

  # MySQL/Aurora port dari Elastic Beanstalk
  ingress {
    description     = "MySQL dari Elastic Beanstalk"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.elastic_beanstalk.id]
  }

  # MySQL/Aurora port dari Lambda
  ingress {
    description     = "MySQL dari Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Tidak ada outbound yang eksplisit diperlukan
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

# ---------------------------------------------------------------------------
# Security Group: Lambda Functions
# Lambda di dalam VPC perlu security group
# ---------------------------------------------------------------------------
resource "aws_security_group" "lambda" {
  name        = "${local.name_prefix}-lambda-sg"
  description = "Security group untuk Lambda functions"
  vpc_id      = aws_vpc.main.id

  # Izinkan semua outbound (untuk akses RDS, DynamoDB, S3)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-lambda-sg"
  }
}

# ---------------------------------------------------------------------------
# Security Group: EFS (Elastic File System)
# Hanya menerima NFS dari Elastic Beanstalk
# ---------------------------------------------------------------------------
resource "aws_security_group" "efs" {
  name        = "${local.name_prefix}-efs-sg"
  description = "Security group untuk EFS"
  vpc_id      = aws_vpc.main.id

  # NFS protocol dari Elastic Beanstalk
  ingress {
    description     = "NFS dari Elastic Beanstalk"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.elastic_beanstalk.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-efs-sg"
  }
}
