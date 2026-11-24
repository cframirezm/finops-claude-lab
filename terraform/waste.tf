# ---------------------------------------------------------------------------
# Desperdicio sembrado a propósito. Cada recurso lleva la etiqueta
# Seeded = <patrón> para poder explicarlo en la charla.
# ---------------------------------------------------------------------------

# 1. Disco huérfano (playbook: aws-orphaned-ebs-volumes)
resource "aws_ebs_volume" "orphan" {
  availability_zone = local.az
  size              = 20
  type              = "gp3"
  tags              = { Name = "old-app-data", Seeded = "orphaned-ebs" }
}

# 2. Disco en gp2 que debería ser gp3 (playbook: aws-gp2-to-gp3)
resource "aws_ebs_volume" "gp2" {
  availability_zone = local.az
  size              = 10
  type              = "gp2"
  tags              = { Name = "legacy-gp2", Seeded = "gp2-to-gp3" }
}

# 3. Snapshots acumulados (playbook: aws-snapshot-sprawl)
resource "aws_ebs_snapshot" "sprawl" {
  count     = 3
  volume_id = aws_ebs_volume.orphan.id
  tags      = { Name = "old-app-data-backup-${count.index + 1}", Seeded = "snapshot-sprawl" }
}

# 3b. LA TRAMPA: parece un snapshot viejo más, pero es el único respaldo
#     de algo importante. La etiqueta lo dice; un humano (o una IA bien
#     instruida) tiene que leerla antes de borrar.
resource "aws_ebs_volume" "billing_db" {
  availability_zone = local.az
  size              = 8
  type              = "gp3"
  tags              = { Name = "billing-db-2025", Seeded = "trap-source" }
}

resource "aws_ebs_snapshot" "only_backup" {
  volume_id = aws_ebs_volume.billing_db.id
  tags = {
    Name      = "billing-db-final-backup"
    Seeded    = "trap"
    Retention = "legal-7-years"
    Owner     = "finanzas"
  }
}

# 4. IP pública sin usar (AWS cobra toda IPv4 pública)
resource "aws_eip" "unused" {
  domain = "vpc"
  tags   = { Name = "old-bastion-ip", Seeded = "unused-eip" }
}

# 5. Máquina ociosa: encendida 24/7 sin hacer nada
resource "aws_instance" "idle" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.egress_only.id]
  tags                   = { Name = "reporting-server-old", Seeded = "idle-ec2" }
}

# 6. Bucket sin ciclo de vida (playbook: aws-s3-incomplete-multipart-uploads)
#    Las cargas multiparte incompletas se siembran con scripts/seed-s3.sh
resource "aws_s3_bucket" "logs" {
  bucket_prefix = "finops-lab-logs-"
  force_destroy = true
  tags          = { Seeded = "s3-no-lifecycle" }
}

resource "aws_s3_object" "log" {
  count   = 5
  bucket  = aws_s3_bucket.logs.id
  key     = "app/2025/log-${count.index + 1}.txt"
  content = "log de ejemplo ${count.index + 1}"
}

# 7. NAT Gateway zombi, opcional (playbook: aws-zombie-nat-gateway)
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
