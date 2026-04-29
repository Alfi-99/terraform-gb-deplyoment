# =============================================================================
# LOCALS - Nilai-nilai yang sering digunakan / computed
# =============================================================================
locals {
  # Nama prefix yang konsisten untuk semua resource
  name_prefix = "${var.project_name}-${var.environment}"

  # Nama S3 bucket (harus unik global)
  deployment_bucket_name = var.s3_deployment_bucket_name != "" ? var.s3_deployment_bucket_name : "${local.name_prefix}-deploy-${random_id.bucket_suffix.hex}"
  app_bucket_name        = var.s3_app_bucket_name != "" ? var.s3_app_bucket_name : "${local.name_prefix}-storage-${random_id.bucket_suffix.hex}"

  # Tags tambahan untuk resource tertentu
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  # Warna yang tidak aktif (untuk stanby)
  standby_color = var.active_color == "blue" ? "green" : "blue"
}

# Random suffix untuk bucket name agar unik
resource "random_id" "bucket_suffix" {
  byte_length = 4
}
