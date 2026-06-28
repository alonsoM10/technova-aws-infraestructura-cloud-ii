# ──────────────────────────────────────────────
# CLOUDTRAIL - Auditoría y trazabilidad de la cuenta AWS
# ──────────────────────────────────────────────
# CloudTrail registra todas las llamadas a la API de AWS
# (quién hizo qué, cuándo y desde dónde). Los registros se
# guardan en un bucket S3. Aporta la trazabilidad que aparece
# en el diagrama de arquitectura.

# -------------------------------------------------
# 0. Datos de la cuenta (para construir las policies)
# -------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -------------------------------------------------
# 1. Bucket S3 donde CloudTrail deja los logs
# -------------------------------------------------
# El nombre incluye el ID de cuenta para que sea único global.
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "cloudtrail-${var.proyecto}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # permite borrar el bucket aunque tenga logs (laboratorio)

  tags = {
    Name = "cloudtrail-${var.proyecto}"
  }
}

# Bloquear todo acceso público al bucket de logs (buena práctica)
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -------------------------------------------------
# 2. Policy del bucket - permite que CloudTrail escriba
# -------------------------------------------------
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PermitirCloudTrailVerACL"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "PermitirCloudTrailEscribirLogs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# -------------------------------------------------
# 3. CloudTrail (el "trail" de auditoría)
# -------------------------------------------------
resource "aws_cloudtrail" "technova" {
  name                          = "cloudtrail-${var.proyecto}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true # incluye eventos de servicios globales (IAM, etc.)
  is_multi_region_trail         = true # registra todas las regiones
  enable_log_file_validation    = true # permite verificar que los logs no se alteraron

  # Asegura que la policy del bucket exista antes de crear el trail
  depends_on = [aws_s3_bucket_policy.cloudtrail]

  tags = {
    Name = "cloudtrail-${var.proyecto}"
  }
}
