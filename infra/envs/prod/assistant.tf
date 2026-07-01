# --- AI resume assistant backend ---
# Replaces the old visitor counter. Chat widget on the static site calls
# https://<assistant_subdomain>.<domain_name>/chat, which is backed by a
# Lambda that calls the Anthropic API, grounded on assistant/knowledge.json.

# Anthropic API key. The secret container is managed here, but its value is
# NOT set via Terraform (so it never touches state or git history). After
# `terraform apply`, set it once with:
#   aws secretsmanager put-secret-value \
#     --secret-id cloud-resume/anthropic-api-key \
#     --secret-string "sk-ant-..."
resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name        = "cloud-resume/anthropic-api-key"
  description = "Anthropic API key for the resume assistant Lambda. Value set out-of-band, not via Terraform."
}

# --- Per-IP rate limiting (secondary defense behind the WAF rate rule) ---
resource "aws_dynamodb_table" "assistant_rate_limit" {
  name         = "cloud-resume-assistant-rate-limit"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

# --- Lambda packaging ---
data "archive_file" "assistant_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../assistant"
  output_path = "${path.module}/.build/assistant.zip"
}

resource "aws_cloudwatch_log_group" "assistant_lambda" {
  name              = "/aws/lambda/cloud-resume-assistant"
  retention_in_days = 14
}

resource "aws_iam_role" "assistant_lambda" {
  name = "cloud-resume-assistant-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "assistant_lambda" {
  name = "cloud-resume-assistant-lambda"
  role = aws_iam_role.assistant_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.assistant_lambda.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.anthropic_api_key.arn
      },
      {
        Effect   = "Allow"
        Action   = "dynamodb:UpdateItem"
        Resource = aws_dynamodb_table.assistant_rate_limit.arn
      }
    ]
  })
}

resource "aws_lambda_function" "assistant" {
  function_name    = "cloud-resume-assistant"
  role             = aws_iam_role.assistant_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  timeout          = 20
  memory_size      = 256
  filename         = data.archive_file.assistant_lambda.output_path
  source_code_hash = data.archive_file.assistant_lambda.output_base64sha256

  environment {
    variables = {
      ANTHROPIC_SECRET_ARN    = aws_secretsmanager_secret.anthropic_api_key.arn
      ANTHROPIC_MODEL         = var.anthropic_model
      RATE_LIMIT_TABLE        = aws_dynamodb_table.assistant_rate_limit.name
      MAX_REQUESTS_PER_WINDOW = tostring(var.assistant_rate_limit_max_requests)
      WINDOW_SECONDS          = tostring(var.assistant_rate_limit_window_seconds)
    }
  }

  depends_on = [aws_cloudwatch_log_group.assistant_lambda]
}

# --- HTTP API ---
resource "aws_apigatewayv2_api" "assistant" {
  name          = "cloud-resume-assistant"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${var.domain_name}", "https://${var.www_domain_name}"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_integration" "assistant" {
  api_id                 = aws_apigatewayv2_api.assistant.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.assistant.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "assistant_chat" {
  api_id    = aws_apigatewayv2_api.assistant.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.assistant.id}"
}

resource "aws_cloudwatch_log_group" "assistant_api_access" {
  name              = "/aws/apigateway/cloud-resume-assistant"
  retention_in_days = 14
}

resource "aws_apigatewayv2_stage" "assistant" {
  api_id      = aws_apigatewayv2_api.assistant.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.assistant_api_access.arn
    format = jsonencode({
      requestId = "$context.requestId"
      ip        = "$context.identity.sourceIp"
      status    = "$context.status"
      path      = "$context.path"
      latency   = "$context.responseLatency"
    })
  }
}

resource "aws_lambda_permission" "assistant_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.assistant.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.assistant.execution_arn}/*/*"
}

# --- Custom domain: api.<domain_name> ---
resource "aws_acm_certificate" "assistant_api" {
  domain_name       = "${var.assistant_subdomain}.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "assistant_api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.assistant_api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.primary.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "assistant_api" {
  certificate_arn         = aws_acm_certificate.assistant_api.arn
  validation_record_fqdns = [for r in aws_route53_record.assistant_api_cert_validation : r.fqdn]
}

resource "aws_apigatewayv2_domain_name" "assistant" {
  domain_name = "${var.assistant_subdomain}.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.assistant_api.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "assistant" {
  api_id      = aws_apigatewayv2_api.assistant.id
  domain_name = aws_apigatewayv2_domain_name.assistant.id
  stage       = aws_apigatewayv2_stage.assistant.id
}

resource "aws_route53_record" "assistant_api" {
  zone_id         = data.aws_route53_zone.primary.zone_id
  name            = "${var.assistant_subdomain}.${var.domain_name}"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_apigatewayv2_domain_name.assistant.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.assistant.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# WAFv2 AssociateWebACL does not support API Gateway HTTP APIs (v2) — only
# REST APIs (v1), ALBs, and AppSync. Rate limiting is handled by the API
# Gateway stage throttle settings and the DynamoDB per-IP check in the Lambda.
