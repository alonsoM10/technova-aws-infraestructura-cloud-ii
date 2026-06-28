# ──────────────────────────────────────────────
# OUTPUTS - Valores útiles tras el despliegue
# ──────────────────────────────────────────────

output "alb_dns" {
  description = "DNS público del ALB - aquí accedes a la aplicación"
  value       = "http://${aws_lb.technova.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint de conexión de la base de datos RDS"
  value       = aws_db_instance.technova.endpoint
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.technova.id
}

output "asg_nombre" {
  description = "Nombre del Auto Scaling Group"
  value       = aws_autoscaling_group.technova.name
}

output "sns_topic_arn" {
  description = "ARN del tema SNS de alertas"
  value       = aws_sns_topic.alertas.arn
}

output "dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.technova.dashboard_name}"
}

output "backup_vault" {
  description = "Nombre de la bóveda de AWS Backup"
  value       = aws_backup_vault.technova.name
}

output "cloudtrail_bucket" {
  description = "Bucket S3 donde CloudTrail guarda los registros de auditoría"
  value       = aws_s3_bucket.cloudtrail.id
}
