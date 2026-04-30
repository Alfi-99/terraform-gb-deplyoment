# =============================================================================
# API GATEWAY - REST API
# Titik masuk semua request API dari client
# Free tier: 1 juta API calls per bulan
# =============================================================================

# REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name_prefix}-api"
  description = "REST API untuk ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"] # REGIONAL lebih murah dari EDGE
  }

  # Policy yang mengizinkan akses dari VPC dan internet
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "execute-api:/*/*/*"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-api"
  }
}

# ---------------------------------------------------------------------------
# Resources dan Methods
# ---------------------------------------------------------------------------

# Resource: /items
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "items"
}

# Resource: /items/{id}
resource "aws_api_gateway_resource" "item_by_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}"
}

# Resource: /health (health check endpoint)
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "health"
}

# ---------------------------------------------------------------------------
# GET /items - List semua items
# ---------------------------------------------------------------------------
resource "aws_api_gateway_method" "get_items" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE" # Ganti dengan COGNITO_USER_POOLS untuk auth

  request_parameters = {
    "method.request.querystring.limit"  = false
    "method.request.querystring.offset" = false
  }
}

resource "aws_api_gateway_integration" "get_items" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.get_items.http_method
  integration_http_method = "POST" # Lambda selalu dipanggil dengan POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_get.invoke_arn

  timeout_milliseconds = 29000
}

# ---------------------------------------------------------------------------
# GET /items/{id} - Ambil item berdasarkan ID
# ---------------------------------------------------------------------------
resource "aws_api_gateway_method" "get_item_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.item_by_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "get_item_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.item_by_id.id
  http_method             = aws_api_gateway_method.get_item_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_get.invoke_arn

  timeout_milliseconds = 29000
}

# ---------------------------------------------------------------------------
# POST /items - Buat item baru
# ---------------------------------------------------------------------------
resource "aws_api_gateway_method" "post_items" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_items" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.post_items.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_post.invoke_arn

  timeout_milliseconds = 29000
}

# ---------------------------------------------------------------------------
# PUT /items/{id} - Update item
# ---------------------------------------------------------------------------
resource "aws_api_gateway_method" "put_item" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.item_by_id.id
  http_method   = "PUT"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "put_item" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.item_by_id.id
  http_method             = aws_api_gateway_method.put_item.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_post.invoke_arn

  timeout_milliseconds = 29000
}

# ---------------------------------------------------------------------------
# DELETE /items/{id} - Hapus item
# ---------------------------------------------------------------------------
resource "aws_api_gateway_method" "delete_item" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.item_by_id.id
  http_method   = "DELETE"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "delete_item" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.item_by_id.id
  http_method             = aws_api_gateway_method.delete_item.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_post.invoke_arn

  timeout_milliseconds = 29000
}

# ---------------------------------------------------------------------------
# GET /health - Health check endpoint
# ---------------------------------------------------------------------------
resource "aws_api_gateway_method" "health_check" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_check" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_check.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "health_check_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_check.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "health_check" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_check.http_method
  status_code = aws_api_gateway_method_response.health_check_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = jsonencode({
      status  = "healthy"
      service = var.project_name
    })
  }
}

# ---------------------------------------------------------------------------
# Deployment dan Stage
# ---------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  # Trigger re-deployment ketika ada perubahan
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.items.id,
      aws_api_gateway_resource.item_by_id.id,
      aws_api_gateway_method.get_items.id,
      aws_api_gateway_method.post_items.id,
      aws_api_gateway_method.get_item_by_id.id,
      aws_api_gateway_method.put_item.id,
      aws_api_gateway_method.delete_item.id,
      aws_api_gateway_integration.get_items.id,
      aws_api_gateway_integration.post_items.id,
      aws_api_gateway_integration.get_item_by_id.id,
      aws_api_gateway_integration.put_item.id,
      aws_api_gateway_integration.delete_item.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage API Gateway
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  # Access logging ke CloudWatch
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      protocol       = "$context.protocol"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  # X-Ray tracing
  xray_tracing_enabled = true

  # Throttling diset via aws_api_gateway_method_settings

  tags = {
    Name = "${local.name_prefix}-api-stage"
  }
}

# CloudWatch Log Group untuk API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${local.name_prefix}"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-api-gateway-logs"
  }
}

# Pendaftaran IAM Role di tingkat akun untuk API Gateway logging
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging.arn
}

resource "aws_iam_role" "api_gateway_logging" {
  name = "${local.name_prefix}-api-gw-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_logging" {
  role       = aws_iam_role.api_gateway_logging.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Method Settings: Throttling per method
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*" # Apply ke semua methods

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
    throttling_rate_limit  = 1000  # Max 1000 requests/detik
    throttling_burst_limit = 500   # Max 500 requests burst
  }
}

# Usage Plan (untuk rate limiting di free tier)
resource "aws_api_gateway_usage_plan" "main" {
  name        = "${local.name_prefix}-usage-plan"
  description = "Usage plan untuk ${var.project_name} - Free tier friendly"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = 1000000 # 1 juta request per bulan (free tier limit)
    offset = 0
    period = "MONTH"
  }

  # Throttling settings untuk REST API v1 dilakukan melalui resource aws_api_gateway_method_settings jika diperlukan.
  # Blok default_route_settings dihapus karena tidak kompatibel.

  throttle_settings {
    burst_limit = 500
    rate_limit  = 1000
  }
}
