# ──────────────────────────────────────────────
# BACKUP - AWS Backup para EC2 y RDS
# ──────────────────────────────────────────────
# Cubre el indicador IE1.5: planes de respaldo automatizados.
# AWS Backup centraliza los snapshots de EBS (EC2) y de RDS
# con políticas de retención y ciclo de vida.

# -------------------------------------------------
# 1. Bóveda de respaldos (Backup Vault)
# -------------------------------------------------
resource "aws_backup_vault" "technova" {
  name = "vault-${var.proyecto}"

  tags = {
    Name = "vault-${var.proyecto}"
  }
}

# -------------------------------------------------
# 2. Plan de respaldo - regla diaria
# -------------------------------------------------
resource "aws_backup_plan" "technova" {
  name = "plan-backup-${var.proyecto}"

  rule {
    rule_name         = "respaldo-diario"
    target_vault_name = aws_backup_vault.technova.name

    # Snapshot diario a las 05:00 UTC
    schedule = "cron(0 5 * * ? *)"

    # Ventana de inicio y duración del job
    start_window      = 60   # minutos para iniciar
    completion_window = 180  # minutos para completar

    # Ciclo de vida: retener cada respaldo 30 días
    lifecycle {
      delete_after = 30
    }
  }

  tags = {
    Name = "plan-backup-${var.proyecto}"
  }
}

# -------------------------------------------------
# 3. Rol IAM que AWS Backup usa para respaldar
# -------------------------------------------------
# NOTA AWS Academy: el Learner Lab normalmente NO permite crear
# roles IAM. Si tu lab lo bloquea, usa el rol preexistente
# "LabRole" en lugar de este recurso (ver outputs.tf).
resource "aws_iam_role" "backup" {
  name = "rol-backup-${var.proyecto}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# -------------------------------------------------
# 4. Selección de recursos a respaldar (EC2 + RDS)
# -------------------------------------------------
# Selecciona por etiqueta: todo recurso con Proyecto=TechNova
# queda incluido en el plan (las EC2 del ASG y la RDS).
resource "aws_backup_selection" "technova" {
  name         = "seleccion-${var.proyecto}"
  plan_id      = aws_backup_plan.technova.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Proyecto"
    value = "TechNova"
  }
}
