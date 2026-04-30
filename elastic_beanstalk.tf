# =============================================================================
# ELASTIC BEANSTALK - Blue/Green Deployment
# Environment BLUE dan GREEN berjalan bersamaan
# ALB menentukan mana yang menerima traffic
# =============================================================================

# ---------------------------------------------------------------------------
# Data Source: Mencari platform version terbaru untuk Node.js 20
# ---------------------------------------------------------------------------
data "aws_elastic_beanstalk_solution_stack" "nodejs" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023 v.* running Node.js 20$"
}

# ---------------------------------------------------------------------------
# Elastic Beanstalk Application
# ---------------------------------------------------------------------------
resource "aws_elastic_beanstalk_application" "main" {
  name        = "${local.name_prefix}-app"
  description = "Aplikasi ${var.project_name} dengan Blue/Green deployment"

  appversion_lifecycle {
    service_role          = aws_iam_role.eb_service_role.arn
    max_count             = 10 # Simpan max 10 versi terakhir
    delete_source_from_s3 = true
  }
}

# ---------------------------------------------------------------------------
# Application Version - Versi yang di-deploy
# Dibuat dari ZIP file di S3
# ---------------------------------------------------------------------------
resource "aws_elastic_beanstalk_application_version" "blue" {
  name        = "v100blue" # Disederhanakan (hanya huruf & angka)
  application = aws_elastic_beanstalk_application.main.name
  description = "Blue environment version"
  bucket      = aws_s3_bucket.deployment.id
  key         = "deployments/v100blue/app.zip"
}

resource "aws_elastic_beanstalk_application_version" "green" {
  name        = "v101green" # Disederhanakan
  application = aws_elastic_beanstalk_application.main.name
  description = "Green environment version"
  bucket      = aws_s3_bucket.deployment.id
  key         = "deployments/v101green/app.zip"
}

# ---------------------------------------------------------------------------
# Konfigurasi settings yang SAMA untuk Blue dan Green
# ---------------------------------------------------------------------------
locals {
  eb_settings = [
    # Instance settings
    {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "InstanceType"
      value     = var.eb_instance_type
    },
    {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "IamInstanceProfile"
      value     = aws_iam_instance_profile.eb_instance_profile.name
    },
    # Auto scaling
    {
      namespace = "aws:autoscaling:asg"
      name      = "MinSize"
      value     = tostring(var.eb_min_instances)
    },
    {
      namespace = "aws:autoscaling:asg"
      name      = "MaxSize"
      value     = tostring(var.eb_max_instances)
    },
    # VPC Configuration - Private subnet
    {
      namespace = "aws:ec2:vpc"
      name      = "VPCId"
      value     = aws_vpc.main.id
    },
    {
      namespace = "aws:ec2:vpc"
      name      = "Subnets"
      value     = join(",", aws_subnet.private[*].id)
    },
    {
      namespace = "aws:ec2:vpc"
      name      = "ELBSubnets"
      value     = join(",", aws_subnet.public[*].id)
    },
    {
      namespace = "aws:ec2:vpc"
      name      = "AssociatePublicIpAddress"
      value     = "false"
    },
    # Load Balancer - Gunakan ALB yang sudah dibuat
    {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "EnvironmentType"
      value     = "LoadBalanced"
    },
    {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "LoadBalancerType"
      value     = "application"
    },
    {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "ServiceRole"
      value     = aws_iam_role.eb_service_role.arn
    },
    # Health reporting
    {
      namespace = "aws:elasticbeanstalk:healthreporting:system"
      name      = "SystemType"
      value     = "enhanced"
    },
    # Environment variables - Aplikasi kita
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "NODE_ENV"
      value     = var.environment
    },
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "AWS_REGION"
      value     = var.aws_region
    },
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "S3_BUCKET"
      value     = aws_s3_bucket.app_storage.bucket
    },
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "DYNAMODB_LOG_TABLE"
      value     = aws_dynamodb_table.app_logs.name
    },
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "DB_SECRET_ARN"
      value     = aws_secretsmanager_secret.db_credentials.arn
    },
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "API_GATEWAY_URL"
      value     = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
    },
    # EFS Configuration
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "EFS_ID"
      value     = aws_efs_file_system.main.id
    },
    # Managed updates
    {
      namespace = "aws:elasticbeanstalk:managedactions"
      name      = "ManagedActionsEnabled"
      value     = "true"
    },
    {
      namespace = "aws:elasticbeanstalk:managedactions"
      name      = "PreferredStartTime"
      value     = "Sun:02:00"
    },
    {
      namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
      name      = "UpdateLevel"
      value     = "minor"
    },
    # CloudWatch Logs
    {
      namespace = "aws:elasticbeanstalk:cloudwatch:logs"
      name      = "StreamLogs"
      value     = "true"
    },
    {
      namespace = "aws:elasticbeanstalk:cloudwatch:logs"
      name      = "DeleteOnTerminate"
      value     = "false"
    },
    {
      namespace = "aws:elasticbeanstalk:cloudwatch:logs"
      name      = "RetentionInDays"
      value     = "7"
    },
    # Rolling deployment
    {
      namespace = "aws:elasticbeanstalk:command"
      name      = "DeploymentPolicy"
      value     = "Rolling"
    },
    {
      namespace = "aws:elasticbeanstalk:command"
      name      = "BatchSizeType"
      value     = "Percentage"
    },
    {
      namespace = "aws:elasticbeanstalk:command"
      name      = "BatchSize"
      value     = "50"
    }
  ]
}

# ---------------------------------------------------------------------------
# Environment BLUE
# ---------------------------------------------------------------------------
resource "aws_elastic_beanstalk_environment" "blue" {
  name                = "koperasi-blue" # Nama lebih pendek dan aman
  application         = aws_elastic_beanstalk_application.main.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.nodejs.name
  version_label       = aws_elastic_beanstalk_application_version.blue.name
  wait_for_ready_timeout = "40m"

  # Security group untuk EC2
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.elastic_beanstalk.id
  }

  # Gunakan Target Group BLUE dari ALB
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SharedLoadBalancer"
    value     = aws_lb.main.arn
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "DefaultProcess"
    value     = "bluedefault"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:bluedefault"
    name      = "Port"
    value     = "80"
  }

  # Environment identifier
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DEPLOYMENT_COLOR"
    value     = "blue"
  }

  dynamic "setting" {
    for_each = local.eb_settings
    content {
      namespace = setting.value.namespace
      name      = setting.value.name
      value     = setting.value.value
    }
  }

  tags = {
    Name  = "${local.name_prefix}-blue-env"
    Color = "blue"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eb_web_tier,
    aws_iam_role_policy_attachment.eb_worker_tier,
    aws_iam_role_policy_attachment.eb_enhanced_health
  ]
}

# ---------------------------------------------------------------------------
# Environment GREEN
# ---------------------------------------------------------------------------
resource "aws_elastic_beanstalk_environment" "green" {
  name                = "koperasi-green" # Nama lebih pendek dan aman
  application         = aws_elastic_beanstalk_application.main.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.nodejs.name
  version_label       = aws_elastic_beanstalk_application_version.green.name
  wait_for_ready_timeout = "40m"

  # Security group untuk EC2
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.elastic_beanstalk.id
  }

  # Gunakan Target Group GREEN dari ALB
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SharedLoadBalancer"
    value     = aws_lb.main.arn
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "DefaultProcess"
    value     = "greendefault"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:greendefault"
    name      = "Port"
    value     = "80"
  }

  # Environment identifier
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DEPLOYMENT_COLOR"
    value     = "green"
  }

  dynamic "setting" {
    for_each = local.eb_settings
    content {
      namespace = setting.value.namespace
      name      = setting.value.name
      value     = setting.value.value
    }
  }

  tags = {
    Name  = "${local.name_prefix}-green-env"
    Color = "green"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eb_web_tier,
    aws_iam_role_policy_attachment.eb_worker_tier,
    aws_iam_role_policy_attachment.eb_enhanced_health
  ]
}
