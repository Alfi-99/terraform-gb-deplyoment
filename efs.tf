# =============================================================================
# EFS - Elastic File System
# Shared storage yang bisa di-mount ke semua EC2 instance Elastic Beanstalk
# Ideal untuk file yang perlu diakses oleh semua instance (session, uploads, dll)
# =============================================================================

# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token   = "${local.name_prefix}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting" # Free tier compatible

  # Enkripsi at rest
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS" # Pindah ke Infrequent Access setelah 30 hari
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name = "${local.name_prefix}-efs"
  }
}

# EFS Mount Targets - Satu per private subnet
# Mount target memungkinkan EC2 instance di subnet tersebut mengakses EFS
resource "aws_efs_mount_target" "private" {
  count = length(aws_subnet.private)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# EFS Access Point - Akses terbatas ke direktori tertentu
resource "aws_efs_access_point" "app" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/app-data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${local.name_prefix}-efs-ap"
  }
}

# EFS Access Point untuk uploads
resource "aws_efs_access_point" "uploads" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/uploads"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }

  tags = {
    Name = "${local.name_prefix}-efs-uploads-ap"
  }
}

# EFS Backup Policy
resource "aws_efs_backup_policy" "main" {
  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"
  }
}
