# =============================================================================
# DYNAMODB - Log Storage
# Menyimpan semua log dari Lambda, Elastic Beanstalk, dan API Gateway
# Free tier: 25GB storage, 25 WCU, 25 RCU
# =============================================================================

# ---------------------------------------------------------------------------
# Tabel Utama: Application Logs
# Menyimpan semua log dari semua service
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "app_logs" {
  name         = "${local.name_prefix}-app-logs"
  billing_mode = var.dynamodb_billing_mode # PAY_PER_REQUEST untuk free tier

  # Primary key: service#timestamp (untuk query per service)
  hash_key  = "service_id"  # Partition key: nama service (lambda-post, lambda-get, eb-blue, dll)
  range_key = "timestamp"   # Sort key: timestamp ISO 8601

  # Attribute definitions
  attribute {
    name = "service_id"
    type = "S" # String
  }

  attribute {
    name = "timestamp"
    type = "S" # String (ISO 8601)
  }

  attribute {
    name = "log_level"
    type = "S" # INFO, WARN, ERROR
  }

  attribute {
    name = "request_id"
    type = "S" # Request ID untuk tracing
  }

  # Global Secondary Index: Query berdasarkan log level
  global_secondary_index {
    name               = "log-level-index"
    hash_key           = "log_level"
    range_key          = "timestamp"
    projection_type    = "ALL"
  }

  # Global Secondary Index: Query berdasarkan request ID (distributed tracing)
  global_secondary_index {
    name               = "request-id-index"
    hash_key           = "request_id"
    range_key          = "timestamp"
    projection_type    = "INCLUDE"
    non_key_attributes = ["service_id", "log_level", "message"]
  }

  # TTL: Hapus log lama otomatis (hemat storage)
  ttl {
    attribute_name = "expire_at" # Unix timestamp
    enabled        = true
  }

  # Point-in-time recovery (gratis)
  point_in_time_recovery {
    enabled = true
  }

  # Enkripsi at rest dengan AWS managed key (gratis)
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name    = "${local.name_prefix}-app-logs"
    Purpose = "Application Logging"
  }
}

# ---------------------------------------------------------------------------
# Tabel: API Request Logs
# Menyimpan log khusus untuk setiap API request
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "api_request_logs" {
  name         = "${local.name_prefix}-api-requests"
  billing_mode = var.dynamodb_billing_mode

  hash_key  = "request_id"
  range_key = "timestamp"

  attribute {
    name = "request_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "endpoint"
    type = "S"
  }

  attribute {
    name = "status_code"
    type = "S"
  }

  # Index untuk query per endpoint
  global_secondary_index {
    name            = "endpoint-index"
    hash_key        = "endpoint"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # Index untuk query per status code
  global_secondary_index {
    name            = "status-code-index"
    hash_key        = "status_code"
    range_key       = "timestamp"
    projection_type = "INCLUDE"
    non_key_attributes = ["request_id", "endpoint", "duration_ms"]
  }

  ttl {
    attribute_name = "expire_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name    = "${local.name_prefix}-api-requests"
    Purpose = "API Request Logging"
  }
}

# ---------------------------------------------------------------------------
# Tabel: Deployment History
# Mencatat riwayat deployment Blue/Green
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "deployment_history" {
  name         = "${local.name_prefix}-deployments"
  billing_mode = var.dynamodb_billing_mode

  hash_key  = "deployment_id"
  range_key = "timestamp"

  attribute {
    name = "deployment_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "color"
    type = "S"
  }

  # Index untuk query per color (blue/green)
  global_secondary_index {
    name            = "color-index"
    hash_key        = "color"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expire_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name    = "${local.name_prefix}-deployments"
    Purpose = "Deployment History Tracking"
  }
}
