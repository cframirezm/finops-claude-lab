# ---------------------------------------------------------------------------
# Detección continua: EventBridge Scheduler -> Lambda -> SNS
# La Lambda solo LEE y ETIQUETA (finops:candidate). Nunca borra.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "report" {
  name = "finops-lab-report"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.report.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "archive_file" "detector" {
  type        = "zip"
  source_file = "${path.module}/../lambda/detector.py"
  output_path = "${path.module}/build/detector.zip"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "detector" {
  name               = "finops-lab-detector"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "detector" {
  statement {
    sid = "ReadOnly"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeNatGateways",
      "cloudwatch:GetMetricStatistics",
      "s3:ListAllMyBuckets",
      "s3:GetLifecycleConfiguration",
      "s3:ListBucketMultipartUploads",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "TagOnly"
    actions   = ["ec2:CreateTags"]
    resources = ["*"]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = ["finops:candidate", "finops:monthly-usd"]
    }
  }
  statement {
    sid       = "Report"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.report.arn]
  }
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "detector" {
  role   = aws_iam_role.detector.id
  policy = data.aws_iam_policy_document.detector.json
}

resource "aws_lambda_function" "detector" {
  function_name    = "finops-lab-detector"
  role             = aws_iam_role.detector.arn
  runtime          = "python3.12"
  handler          = "detector.handler"
  filename         = data.archive_file.detector.output_path
  source_code_hash = data.archive_file.detector.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      TOPIC_ARN         = aws_sns_topic.report.arn
      SNAPSHOT_AGE_DAYS = tostring(var.snapshot_age_days)
    }
  }
}

data "aws_iam_policy_document" "scheduler_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "finops-lab-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_trust.json
}

resource "aws_iam_role_policy" "scheduler" {
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.detector.arn
    }]
  })
}

resource "aws_scheduler_schedule" "detector" {
  name                = "finops-lab-detector"
  schedule_expression = var.detection_schedule
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_function.detector.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
