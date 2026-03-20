# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    route53        = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
    elb            = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
    rds            = "http://localhost:4566"
    autoscaling    = "http://localhost:4566"
    events         = "http://localhost:4566"
    kms            = "http://localhost:4566"
  }
}

# KMS Key: The encryption foundation for our secrets
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "secrets-rotation-kms-key"
    Environment = "SysOps-Lab"
  }
}

# KMS Alias: Provides a friendly name for the KMS key
resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/secrets-management-key"
  target_key_id = aws_kms_key.secrets_key.key_id
}

# Secrets Manager Secret: Container for our sensitive database credentials
resource "aws_secretsmanager_secret" "db_password" {
  name        = "sysops-lab-db-password"
  description = "Managed database password for SysOps lab"
  kms_key_id  = aws_kms_key.secrets_key.arn

  tags = {
    Name        = "db-password-secret"
    Environment = "SysOps-Lab"
  }
}

# IAM Role: Identity for the automated secret rotation Lambda
resource "aws_iam_role" "rotation_lambda_role" {
  name = "secret-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "rotation-lambda-role"
    Environment = "SysOps-Lab"
  }
}

# Secret Version: Initial value for our database password
resource "aws_secretsmanager_secret_version" "initial_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "admin"
    password = "initial-secure-password-123"
  })
}

# IAM Policy: Grants the Lambda permission to rotate the secret and use the KMS key
resource "aws_iam_role_policy" "rotation_lambda_policy" {
  name = "secret-rotation-lambda-policy"
  role = aws_iam_role.rotation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetRandomPassword"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.secrets_key.arn
      }
    ]
  })
}

# Lambda Function: The automation engine for secret rotation
resource "aws_lambda_function" "rotation_lambda" {
  filename      = "rotation.zip"
  function_name = "db-password-rotation-function"
  role          = aws_iam_role.rotation_lambda_role.arn
  handler       = "rotation.handler"
  runtime       = "python3.9"

  tags = {
    Name        = "rotation-lambda-function"
    Environment = "SysOps-Lab"
  }
}

# Lambda Permission: Allows Secrets Manager to invoke our rotation function
resource "aws_lambda_permission" "allow_secrets_manager" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation_lambda.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# Secret Rotation: Connects the secret to the Lambda and sets the schedule
resource "aws_secretsmanager_secret_rotation" "db_password_rotation" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rotation_lambda.arn

  rotation_rules {
    automatically_after_days = 30
  }

  # Ensure the Lambda has permission before enabling rotation
  depends_on = [aws_lambda_permission.allow_secrets_manager]
}

# Outputs: Key identifiers for verifying the secret rotation architecture
output "secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}

output "rotation_lambda_arn" {
  value = aws_lambda_function.rotation_lambda.arn
}

output "kms_key_id" {
  value = aws_kms_key.secrets_key.key_id
}
