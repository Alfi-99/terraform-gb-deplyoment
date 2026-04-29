# =============================================================================
# S3 BUCKETS
# =============================================================================

# ---------------------------------------------------------------------------
# S3 Bucket: Deployment Artifacts
# Menyimpan application bundle dari GitHub Actions
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "deployment" {
  bucket = local.deployment_bucket_name

  tags = {
    Name    = "${local.name_prefix}-deployment"
    Purpose = "CI/CD Deployment Artifacts"
  }
}

# Versioning untuk deployment bucket (track setiap version)
resource "aws_s3_bucket_versioning" "deployment" {
  bucket = aws_s3_bucket.deployment.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enkripsi deployment bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access untuk deployment bucket
resource "aws_s3_bucket_public_access_block" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy: hapus versi lama setelah 30 hari
resource "aws_s3_bucket_lifecycle_configuration" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}

# ---------------------------------------------------------------------------
# S3 Bucket: Application Storage
# Untuk menyimpan file upload, assets, dll
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "app_storage" {
  bucket = local.app_bucket_name

  tags = {
    Name    = "${local.name_prefix}-storage"
    Purpose = "Application File Storage"
  }
}

# Versioning untuk app storage
resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enkripsi app storage
resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access untuk app storage
resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration untuk app storage (agar frontend bisa upload)
resource "aws_s3_bucket_cors_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"] # Ganti dengan domain Amplify Anda di production
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Lifecycle policy untuk app storage
resource "aws_s3_bucket_lifecycle_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    # Pindahkan ke Infrequent Access setelah 30 hari (lebih murah)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Hapus setelah 365 hari (sesuaikan dengan kebutuhan)
    expiration {
      days = 365
    }
  }
}
