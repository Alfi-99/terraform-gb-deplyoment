# =============================================================================
# LAMBDA FUNCTIONS
# POST handler dan GET handler untuk API Gateway
# Free tier: 1 juta request/bulan, 400.000 GB-detik compute
# =============================================================================

# ---------------------------------------------------------------------------
# Lambda Layer: Shared utilities (DB connection, logger, dll)
# ---------------------------------------------------------------------------
data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/layer"
  output_path = "${path.module}/lambda/layer.zip"
}

resource "aws_lambda_layer_version" "shared_utils" {
  filename            = data.archive_file.lambda_layer.output_path
  layer_name          = "${local.name_prefix}-shared-utils"
  source_code_hash    = data.archive_file.lambda_layer.output_base64sha256
  compatible_runtimes = [var.lambda_runtime]
  description         = "Shared utilities: DB connection, DynamoDB logger, response helpers"
}

# ---------------------------------------------------------------------------
# Lambda Function: POST Handler
# Menangani semua request POST (Create, Update, Delete data)
# ---------------------------------------------------------------------------
data "archive_file" "lambda_post" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/post-handler"
  output_path = "${path.module}/lambda/post-handler.zip"
}

resource "aws_lambda_function" "api_post" {
  filename         = data.archive_file.lambda_post.output_path
  function_name    = "${local.name_prefix}-api-post"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  source_code_hash = data.archive_file.lambda_post.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  layers = [aws_lambda_layer_version.shared_utils.arn]

  # Jalankan Lambda di dalam VPC agar bisa akses RDS
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Environment variables
  environment {
    variables = {
      NODE_ENV              = var.environment
      AWS_REGION_NAME       = var.aws_region
      DB_SECRET_ARN         = aws_secretsmanager_secret.db_credentials.arn
      DYNAMODB_LOG_TABLE    = aws_dynamodb_table.app_logs.name
      DYNAMODB_API_TABLE    = aws_dynamodb_table.api_request_logs.name
      S3_BUCKET             = aws_s3_bucket.app_storage.bucket
      FUNCTION_TYPE         = "POST"
      LOG_LEVEL             = "INFO"
      LOG_TTL_DAYS          = "30"   # Log dihapus setelah 30 hari
    }
  }

  # X-Ray tracing untuk debugging
  tracing_config {
    mode = "Active"
  }

  tags = {
    Name     = "${local.name_prefix}-api-post"
    Function = "POST Handler"
  }
}

# CloudWatch Log Group untuk Lambda POST
resource "aws_cloudwatch_log_group" "lambda_post" {
  name              = "/aws/lambda/${aws_lambda_function.api_post.function_name}"
  retention_in_days = 7 # Free tier: simpan 7 hari

  tags = {
    Name = "${local.name_prefix}-lambda-post-logs"
  }
}

# ---------------------------------------------------------------------------
# Lambda Function: GET Handler
# Menangani semua request GET (Read/Query data)
# ---------------------------------------------------------------------------
data "archive_file" "lambda_get" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/get-handler"
  output_path = "${path.module}/lambda/get-handler.zip"
}

resource "aws_lambda_function" "api_get" {
  filename         = data.archive_file.lambda_get.output_path
  function_name    = "${local.name_prefix}-api-get"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  source_code_hash = data.archive_file.lambda_get.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  layers = [aws_lambda_layer_version.shared_utils.arn]

  # Jalankan Lambda di dalam VPC
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Environment variables
  environment {
    variables = {
      NODE_ENV           = var.environment
      AWS_REGION_NAME    = var.aws_region
      DB_SECRET_ARN      = aws_secretsmanager_secret.db_credentials.arn
      DYNAMODB_LOG_TABLE = aws_dynamodb_table.app_logs.name
      DYNAMODB_API_TABLE = aws_dynamodb_table.api_request_logs.name
      S3_BUCKET          = aws_s3_bucket.app_storage.bucket
      FUNCTION_TYPE      = "GET"
      LOG_LEVEL          = "INFO"
      LOG_TTL_DAYS       = "30"
    }
  }

  # X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  tags = {
    Name     = "${local.name_prefix}-api-get"
    Function = "GET Handler"
  }
}

# CloudWatch Log Group untuk Lambda GET
resource "aws_cloudwatch_log_group" "lambda_get" {
  name              = "/aws/lambda/${aws_lambda_function.api_get.function_name}"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-lambda-get-logs"
  }
}

# ---------------------------------------------------------------------------
# Lambda Permission: Izinkan API Gateway invoke Lambda
# ---------------------------------------------------------------------------
resource "aws_lambda_permission" "api_gateway_post" {
  statement_id  = "AllowAPIGatewayInvokePost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_post.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "api_gateway_get" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_get.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*"
}

# ---------------------------------------------------------------------------
# Lambda Alias: Untuk Blue/Green deployment Lambda
# ---------------------------------------------------------------------------
resource "aws_lambda_alias" "api_post_live" {
  name             = "live"
  function_name    = aws_lambda_function.api_post.function_name
  function_version = "$LATEST"
  description      = "Alias live untuk POST handler"
}

resource "aws_lambda_alias" "api_get_live" {
  name             = "live"
  function_name    = aws_lambda_function.api_get.function_name
  function_version = "$LATEST"
  description      = "Alias live untuk GET handler"
}
