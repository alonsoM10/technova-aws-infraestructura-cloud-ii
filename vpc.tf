# ──────────────────────────────────────────────
# VPC - Red de TechNova con cobertura en 2 AZ (HA)
# ──────────────────────────────────────────────
# Cambio clave vs. la arquitectura original:
# antes solo había subnets públicas en us-east-1a.
# Ahora hay subnet pública en 1a Y en 1b, requisito
# para que el ALB y el Auto Scaling Group sean HA.

# -------------------------------------------------
# 1. VPC
# -------------------------------------------------
resource "aws_vpc" "technova" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${var.proyecto}"
  }
}

# -------------------------------------------------
# 2. Subnets
# -------------------------------------------------

# Pública - Web/App en AZ-A (us-east-1a)
resource "aws_subnet" "publica_a" {
  vpc_id                  = aws_vpc.technova.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-publica-web-1a"
  }
}

# Pública - Web/App en AZ-B (us-east-1b)  ← NUEVA, necesaria para HA
resource "aws_subnet" "publica_b" {
  vpc_id                  = aws_vpc.technova.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-publica-web-1b"
  }
}

# Privada - Datos en AZ-A (us-east-1a)
resource "aws_subnet" "privada_datos_a" {
  vpc_id            = aws_vpc.technova.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.az_a

  tags = {
    Name = "subnet-privada-datos-1a"
  }
}

# Privada - Datos en AZ-B (us-east-1b) - obligatoria para RDS Multi-AZ
resource "aws_subnet" "privada_datos_b" {
  vpc_id            = aws_vpc.technova.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az_b

  tags = {
    Name = "subnet-privada-datos-1b"
  }
}

# -------------------------------------------------
# 3. Internet Gateway
# -------------------------------------------------
resource "aws_internet_gateway" "technova" {
  vpc_id = aws_vpc.technova.id

  tags = {
    Name = "igw-${var.proyecto}"
  }
}

# -------------------------------------------------
# 4. Route Table pública
# -------------------------------------------------
resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.technova.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.technova.id
  }

  tags = {
    Name = "rt-publica-${var.proyecto}"
  }
}

# Asociar las dos subnets públicas a la route table pública
resource "aws_route_table_association" "publica_a" {
  subnet_id      = aws_subnet.publica_a.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table_association" "publica_b" {
  subnet_id      = aws_subnet.publica_b.id
  route_table_id = aws_route_table.publica.id
}
