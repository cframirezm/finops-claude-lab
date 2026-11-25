# ---------------------------------------------------------------------------
# Acceso de Claude a la cuenta: un rol de SOLO LECTURA que asume tu usuario.
# Dos candados: ReadOnlyAccess + un Deny explícito a todo lo que no sea leer,
# y a leer secretos o contenido de objetos.
# Cada llamada queda en CloudTrail (Event history) bajo este rol.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

variable "claude_principal_arn" {
  description = "ARN del usuario o rol que puede asumir el rol de Claude (tu usuario IAM)"
  type        = string
  default     = ""
}

locals {
  claude_principal = var.claude_principal_arn != "" ? var.claude_principal_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cframirezm"
}

data "aws_iam_policy_document" "claude_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [local.claude_principal]
    }
  }
}

resource "aws_iam_role" "claude" {
  name                 = "claude-finops-readonly"
  description          = "Rol de solo lectura para Claude (MCP de AWS) en el laboratorio FinOps"
  assume_role_policy   = data.aws_iam_policy_document.claude_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "claude_readonly" {
  role       = aws_iam_role.claude.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "claude_guardrails" {
  statement {
    sid    = "CostExplorer"
    effect = "Allow"
    actions = [
      "ce:Get*",
      "ce:Describe*",
      "ce:List*",
      "cost-optimization-hub:Get*",
      "cost-optimization-hub:List*",
      "compute-optimizer:Get*",
      "compute-optimizer:Describe*",
    ]
    resources = ["*"]
  }

  # Candado 2: cualquier acción que no sea de lectura queda denegada,
  # aunque mañana alguien le agregue otra política al rol.
  statement {
    sid    = "DenyAnythingNotRead"
    effect = "Deny"
    not_actions = [
      "*:Describe*",
      "*:Get*",
      "*:List*",
      "*:BatchGet*",
      "*:Search*",
      "*:Lookup*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  # Leer metadatos sí; leer datos o secretos, no.
  statement {
    sid    = "DenyReadingData"
    effect = "Deny"
    actions = [
      "s3:GetObject*",
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter*",
      "kms:Decrypt",
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "lambda:GetFunction",
      "ec2:GetPasswordData",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "claude_guardrails" {
  name   = "guardrails"
  role   = aws_iam_role.claude.id
  policy = data.aws_iam_policy_document.claude_guardrails.json
}

output "claude_role_arn" {
  value = aws_iam_role.claude.arn
}
