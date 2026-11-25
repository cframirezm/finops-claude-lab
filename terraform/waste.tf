# ---------------------------------------------------------------------------
# Desperdicio DevOps moderno, sembrado a propósito.
# Cada recurso lleva la etiqueta Seeded = <patrón> para explicarlo en la charla.
# ---------------------------------------------------------------------------

# 1 y 2. Entornos de preview en ECS Fargate (patrón: schedule blindness)
resource "aws_ecs_cluster" "previews" {
  name = "previews"
}

resource "aws_cloudwatch_log_group" "previews" {
  name = "/ecs/previews"
  # Sin retention_in_days: también es desperdicio (patrón 4)
  tags = { Seeded = "logs-no-retention" }
}

resource "aws_iam_role" "task_exec" {
  name = "finops-lab-task-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "preview" {
  family                   = "preview-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_exec.arn
  container_definitions = jsonencode([{
    name      = "web"
    image     = "public.ecr.aws/nginx/nginx:stable-alpine"
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.previews.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "web"
      }
    }
  }])
}

# El PR se cerró; el entorno sigue encendido
resource "aws_ecs_service" "pr_142" {
  name            = "preview-pr-142"
  cluster         = aws_ecs_cluster.previews.id
  task_definition = aws_ecs_task_definition.preview.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  propagate_tags  = "SERVICE"
  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.egress_only.id]
    assign_public_ip = true
  }
  tags = { Environment = "preview", PullRequest = "142", PullRequestState = "closed", Seeded = "forgotten-preview" }
}

# LA TRAMPA: parece igual de olvidado, pero QA lo usa para validar un release
resource "aws_ecs_service" "pr_151" {
  name            = "preview-pr-151"
  cluster         = aws_ecs_cluster.previews.id
  task_definition = aws_ecs_task_definition.preview.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  propagate_tags  = "SERVICE"
  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.egress_only.id]
    assign_public_ip = true
  }
  tags = {
    Environment        = "preview"
    PullRequest        = "151"
    PullRequestState   = "closed"
    Owner              = "qa"
    "DoNotDelete-until" = "2026-12-10"
    Reason             = "validacion-release-2026-12"
    Seeded             = "trap"
  }
}

# 3. Balanceador sin destinos (playbook: aws-idle-load-balancer)
resource "aws_security_group" "alb" {
  name        = "finops-lab-alb"
  description = "ALB sin entrada publica"
  vpc_id      = aws_vpc.lab.id
}

resource "aws_lb" "orphan" {
  name               = "legacy-api-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb.id]
  tags               = { Seeded = "idle-alb" }
}

resource "aws_lb_target_group" "empty" {
  name        = "legacy-api"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lab.id
  target_type = "ip"
}

resource "aws_lb_listener" "orphan" {
  load_balancer_arn = aws_lb.orphan.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.empty.arn
  }
}

# 4. Logs que nunca expiran
resource "aws_cloudwatch_log_group" "old" {
  for_each = toset(["/aws/lambda/legacy-api", "/aws/codebuild/old-pipeline"])
  name     = each.value
  tags     = { Seeded = "logs-no-retention" }
}

# 5. Imágenes acumuladas: repositorio sin política de ciclo de vida
resource "aws_ecr_repository" "app" {
  name                 = "legacy-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = { Seeded = "ecr-no-lifecycle" }
}

# 6. Lambda sobredimensionada: 3 GB para una tarea trivial
data "archive_file" "oversized" {
  type        = "zip"
  output_path = "${path.module}/build/oversized.zip"
  source {
    filename = "index.py"
    content  = "def handler(event, context):\n    return {\"ok\": True}\n"
  }
}

resource "aws_iam_role" "oversized" {
  name = "finops-lab-oversized"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_lambda_function" "oversized" {
  function_name    = "thumbnail-resizer"
  role             = aws_iam_role.oversized.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.oversized.output_path
  source_code_hash = data.archive_file.oversized.output_base64sha256
  memory_size      = 3008
  tags             = { Seeded = "oversized-lambda" }
}

# 7. IP pública sin usar (AWS cobra toda IPv4 pública)
resource "aws_eip" "unused" {
  domain = "vpc"
  tags   = { Name = "old-bastion-ip", Seeded = "unused-eip" }
}

# 8. Bucket de artefactos sin ciclo de vida
#    (playbook: aws-s3-incomplete-multipart-uploads; se siembra con scripts/seed-s3.sh)
resource "aws_s3_bucket" "logs" {
  bucket_prefix = "finops-lab-artifacts-"
  force_destroy = true
  tags          = { Seeded = "s3-no-lifecycle" }
}

resource "aws_s3_object" "log" {
  count   = 5
  bucket  = aws_s3_bucket.logs.id
  key     = "builds/2025/build-${count.index + 1}.zip"
  content = "artefacto de ejemplo ${count.index + 1}"
}

# 9. NAT para descargar imágenes, opcional
#    (playbook: aws-nat-gateway-endpoint-substitution / aws-zombie-nat-gateway)
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
  tags   = { Name = "finops-lab-nat" }
}

resource "aws_nat_gateway" "zombie" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "legacy-nat", Seeded = "zombie-nat" }
}
