terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "finops-lab", ManagedBy = "terraform" }
  }
}

data "aws_availability_zones" "available" { state = "available" }

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  az = data.aws_availability_zones.available.names[0]
}

# ---------------------------------------------------------------------------
# Red propia del laboratorio (la cuenta puede no tener VPC por defecto)
# ---------------------------------------------------------------------------
resource "aws_vpc" "lab" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "finops-lab" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags                    = { Name = "finops-lab-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.30.2.0/24"
  availability_zone = local.az
  tags              = { Name = "finops-lab-private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Segunda subred pública: un ALB necesita dos zonas de disponibilidad
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.30.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "finops-lab-public-b" }
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "egress_only" {
  name        = "finops-lab-egress-only"
  description = "Sin entrada; solo salida"
  vpc_id      = aws_vpc.lab.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
