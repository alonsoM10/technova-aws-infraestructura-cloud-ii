# ──────────────────────────────────────────────
# PROVIDER - Configuración de Terraform y AWS
# ──────────────────────────────────────────────
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# El provider toma las credenciales de:
#   - variables de entorno (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)
#   - o del archivo ~/.aws/credentials
# En AWS Academy Learner Lab debes pegar las credenciales del botón "AWS Details"
# cada vez que inicies una sesión nueva.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Proyecto = "TechNova"
      Entorno  = "EP2-Cloud-II"
      Gestion  = "Terraform"
    }
  }
}
