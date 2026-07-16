# ──────────────────────────────────────────────
# SECURITY GROUPS - Seguridad por capas (3 niveles)
# ──────────────────────────────────────────────
# Diseño de seguridad en capas:
#   Internet -> SG-ALB -> SG-EC2 -> SG-RDS
# Cada capa solo acepta tráfico de la capa anterior.

# -------------------------------------------------
# 1. SG del ALB - recibe tráfico público web
# -------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "alb-${var.proyecto}-sg"
  description = "SG del Application Load Balancer - HTTP/HTTPS publico"
  vpc_id      = aws_vpc.technova.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # La API del frontend se consume por el puerto 3001 a través del ALB.
  ingress {
    description = "API backend publico (3001)"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida hacia las instancias EC2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-${var.proyecto}-sg"
  }
}

# -------------------------------------------------
# 2. SG de las EC2 - solo recibe tráfico DESDE el ALB
# -------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "ec2-${var.proyecto}-sg"
  description = "SG de instancias EC2 - trafico web solo desde el ALB"
  vpc_id      = aws_vpc.technova.id

  ingress {
    description     = "HTTP solo desde el ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Backend 3001 solo desde el ALB"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.mi_ip]
  }

  egress {
    description = "Salida a internet (ECR, updates, imagenes)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-${var.proyecto}-sg"
  }
}

# -------------------------------------------------
# 3. SG de RDS - solo recibe MySQL DESDE las EC2
# -------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "rds-${var.proyecto}-sg"
  description = "SG de RDS - MySQL solo desde las instancias EC2"
  vpc_id      = aws_vpc.technova.id

  ingress {
    description     = "MySQL 3306 solo desde sg-ec2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-${var.proyecto}-sg"
  }
}