data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# S3 bucket — stores raw inbound emails for Lambda to read
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "emails" {
  bucket = var.email_bucket_name

  tags = merge(var.tags, { Name = var.email_bucket_name })
}

resource "aws_s3_bucket_versioning" "emails" {
  bucket = aws_s3_bucket.emails.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "emails" {
  bucket = aws_s3_bucket.emails.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "emails" {
  bucket                  = aws_s3_bucket.emails.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "emails" {
  bucket = aws_s3_bucket.emails.id
  rule {
    id     = "expire-emails"
    status = "Enabled"
    filter {}
    expiration { days = 7 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

data "aws_iam_policy_document" "emails_bucket_policy" {
  # SES inbound must be able to PutObject to store raw emails
  statement {
    sid     = "AllowSESPuts"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.emails.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "emails" {
  bucket = aws_s3_bucket.emails.id
  policy = data.aws_iam_policy_document.emails_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.emails]
}

# ---------------------------------------------------------------------------
# Lambda — reads raw email from S3, rewrites headers, re-sends via SES
# ---------------------------------------------------------------------------
data "archive_file" "forwarder" {
  type        = "zip"
  source_file = "${path.module}/lambda/forwarder.py"
  output_path = "${path.root}/.terraform/ses-email-forwarder.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid    = "ReadEmailsFromS3"
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.emails.arn}/${var.email_key_prefix}/*"]
  }

  statement {
    sid    = "SendViaSeS"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/*"]
  }

  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"]
  }
}

resource "aws_iam_role" "forwarder" {
  name               = "${replace(var.domain_name, ".", "-")}-email-forwarder"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "forwarder" {
  name   = "email-forwarder-policy"
  role   = aws_iam_role.forwarder.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_cloudwatch_log_group" "forwarder" {
  name              = "/aws/lambda/${replace(var.domain_name, ".", "-")}-email-forwarder"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "forwarder" {
  #checkov:skip=CKV_AWS_115:Reserved concurrency not required for low-volume email forwarder.
  #checkov:skip=CKV_AWS_116:DLQ not required; failures are logged and the SES rule retries.
  #checkov:skip=CKV_AWS_272:Code signing not enforced for internal tooling Lambdas.
  #checkov:skip=CKV_AWS_50:X-Ray tracing optional for email forwarder; CloudWatch logs provide sufficient observability.

  function_name    = "${replace(var.domain_name, ".", "-")}-email-forwarder"
  role             = aws_iam_role.forwarder.arn
  runtime          = "python3.12"
  handler          = "forwarder.handler"
  filename         = data.archive_file.forwarder.output_path
  source_code_hash = data.archive_file.forwarder.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      FORWARDING_MAP   = jsonencode(var.forwarding_aliases)
      FROM_EMAIL       = var.from_email
      EMAIL_BUCKET     = aws_s3_bucket.emails.id
      EMAIL_KEY_PREFIX = var.email_key_prefix
    }
  }

  depends_on = [aws_cloudwatch_log_group.forwarder]

  tags = var.tags
}

resource "aws_lambda_permission" "ses" {
  statement_id  = "AllowSESInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder.function_name
  principal     = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------
# SES receipt rule set + active rule set
# ---------------------------------------------------------------------------
resource "aws_ses_receipt_rule_set" "this" {
  rule_set_name = var.rule_set_name
}

resource "aws_ses_active_receipt_rule_set" "this" {
  rule_set_name = aws_ses_receipt_rule_set.this.rule_set_name
}

resource "aws_ses_receipt_rule" "forward" {
  name          = "${replace(var.domain_name, ".", "-")}-forward"
  rule_set_name = aws_ses_receipt_rule_set.this.rule_set_name
  # Empty recipients list matches all addresses for the verified domain
  recipients    = [var.domain_name]
  enabled       = true
  scan_enabled  = true

  # Action 1: store raw email in S3
  s3_action {
    bucket_name       = aws_s3_bucket.emails.id
    object_key_prefix = "${var.email_key_prefix}/"
    position          = 1
  }

  # Action 2: invoke Lambda to forward
  lambda_action {
    function_arn    = aws_lambda_function.forwarder.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_s3_bucket_policy.emails,
    aws_lambda_permission.ses,
  ]
}

# ---------------------------------------------------------------------------
# MX record — routes inbound mail to SES
# ---------------------------------------------------------------------------
resource "aws_route53_record" "mx" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 600
  records = ["10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com"]
}
