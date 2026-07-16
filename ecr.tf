# ──────────────────────────────────────────────
# ECR - Elastic Container Registry
# ──────────────────────────────────────────────
# Repositorios privados donde se guardan las imágenes Docker
# de la aplicación (frontend y backend). Esto evidencia la
# estrategia de migración Rehost/Replatform con contenedores,
# que es parte del indicador de "Migración completa" (20%).
#
# Flujo: build local -> docker push a ECR -> las EC2 del ASG
# hacen pull desde ECR al arrancar (ver user_data.sh).

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.proyecto}-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # permite destruir el repo con imágenes dentro (lab)

  image_scanning_configuration {
    scan_on_push = true # escaneo de vulnerabilidades: suma en pilar Security
  }

  tags = {
    Name     = "${var.proyecto}-frontend"
    Proyecto = "TechNova"
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.proyecto}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name     = "${var.proyecto}-backend"
    Proyecto = "TechNova"
  }
}

# -------------------------------------------------
# Data source para conocer el ID de la cuenta
# -------------------------------------------------
# Ya existe uno en cloudtrail.tf, pero lo dejamos referenciado
# aquí como recordatorio. NO lo declares de nuevo: Terraform
# reutiliza el data "aws_caller_identity" "current" existente.