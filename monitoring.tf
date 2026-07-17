# ──────────────────────────────────────────────
# MONITORING - CloudWatch (dashboard + alarmas) y SNS
# ──────────────────────────────────────────────
# Cubre el indicador IE1.3 / IE1.4:
#   - Tema SNS con suscripción por correo
#   - Alarmas de CPU y Memoria (umbral configurable, por defecto 70%)
#   - Dashboard con métricas de CPU, memoria, disco y red

# -------------------------------------------------
# 1. Tema SNS para notificaciones
# -------------------------------------------------
resource "aws_sns_topic" "alertas" {
  name = "sns-alertas-${var.proyecto}"

  tags = {
    Name = "sns-alertas-${var.proyecto}"
  }
}

# Suscripción por correo. Recibirás un email de confirmación
# que DEBES aceptar para que lleguen las notificaciones.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "email"
  endpoint  = var.email_alertas
}

# -------------------------------------------------
# 2. Alarma de CPU (a nivel de Auto Scaling Group)
# -------------------------------------------------
# Métrica nativa de EC2. Se evalúa sobre el promedio del ASG.
resource "aws_cloudwatch_metric_alarm" "cpu_alta" {
  alarm_name          = "alarma-cpu-alta-${var.proyecto}"
  alarm_description   = "CPU promedio del ASG supera el umbral"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.umbral_cpu
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.technova.name
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
  ok_actions    = [aws_sns_topic.alertas.arn]
}

# -------------------------------------------------
# 3. Alarma de Memoria (métrica del CloudWatch Agent)
# -------------------------------------------------
# La memoria NO es métrica nativa de EC2: la reporta el agente
# instalado vía user_data (namespace CWAgent).
resource "aws_cloudwatch_metric_alarm" "memoria_alta" {
  alarm_name          = "alarma-memoria-alta-${var.proyecto}"
  alarm_description   = "Uso de memoria supera el umbral"
  namespace           = "CWAgent"
  metric_name         = "MemoriaUsadaPorcentaje"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.umbral_memoria
  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [aws_sns_topic.alertas.arn]
  ok_actions    = [aws_sns_topic.alertas.arn]

  # Si el agente aún no envía datos, no dispara falsas alarmas.
  treat_missing_data = "notBreaching"
}

# -------------------------------------------------
# 4. Alarma de CPU de RDS
# -------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu_alta" {
  alarm_name          = "alarma-rds-cpu-${var.proyecto}"
  alarm_description   = "CPU de la instancia RDS supera el umbral"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.umbral_cpu
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.technova.identifier
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
  ok_actions    = [aws_sns_topic.alertas.arn]
}

# -------------------------------------------------
# 5. Dashboard de CloudWatch
# -------------------------------------------------
# Panel visual con CPU, memoria, disco y red. Útil como
# evidencia gráfica para el informe y la presentación.
resource "aws_cloudwatch_dashboard" "technova" {
  dashboard_name = "dashboard-${var.proyecto}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "CPU - Auto Scaling Group"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.technova.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Memoria - CloudWatch Agent"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["CWAgent", "MemoriaUsadaPorcentaje"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Disco - CloudWatch Agent"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["CWAgent", "DiscoUsadoPorcentaje"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Red y CPU - RDS MySQL"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.technova.identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.technova.identifier]
          ]
        }
      }
    ]
  })
}
