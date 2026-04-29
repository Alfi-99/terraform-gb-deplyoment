# =============================================================================
# AWS AMPLIFY - Frontend Hosting
# Menghubungkan GitHub repository ke Amplify untuk auto-deploy frontend
# Free tier: 1000 build menit/bulan, 5GB storage, 15GB bandwidth
# =============================================================================

resource "aws_amplify_app" "frontend" {
  name       = "${local.name_prefix}-frontend"
  repository = var.github_repo_url

  # OAuth token untuk akses GitHub (atau gunakan OIDC)
  access_token = var.github_access_token

  # Build specification (bisa juga pakai amplify.yml di repo)
  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - npm ci
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: dist
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
  EOT

  # Environment variables untuk frontend
  environment_variables = {
    VITE_API_URL          = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
    VITE_APP_NAME         = var.project_name
    VITE_ENV              = var.environment
    AMPLIFY_DIFF_DEPLOY   = "false"
    AMPLIFY_MONOREPO_APP_ROOT = "frontend"
  }

  # Custom rules: SPA routing (semua path ke index.html)
  custom_rule {
    source = "/<*>"
    status = "404-200"
    target = "/index.html"
  }

  custom_rule {
    source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json)$)([^.]+$)/>"
    status = "200"
    target = "/index.html"
  }

  tags = {
    Name = "${local.name_prefix}-amplify"
  }
}

# Branch connection: Branch main/master
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = var.amplify_branch_name

  # Auto-deploy ketika ada push ke branch ini
  enable_auto_build = true

  # Staging: preview setiap pull request
  enable_pull_request_preview = true

  # Environment variables khusus branch ini
  environment_variables = {
    DEPLOYMENT_COLOR = var.active_color
  }

  tags = {
    Name   = "${local.name_prefix}-amplify-branch"
    Branch = var.amplify_branch_name
  }
}

# Webhook untuk trigger build dari GitHub Actions
resource "aws_amplify_webhook" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = aws_amplify_branch.main.branch_name
  description = "Webhook untuk trigger Amplify build dari GitHub Actions"
}
