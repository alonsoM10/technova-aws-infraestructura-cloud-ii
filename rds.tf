# ──────────────────────────────────────────────
# RDS - Base de datos MySQL en Multi-AZ (Alta Disponibilidad)
# ──────────────────────────────────────────────
# Cambios clave vs. la arquitectura original:
#   - multi_az: false -> TRUE  (instancia standby en otra AZ)
#   - backup_retention_period: 0 -> 7 días (backups automáticos)
# Si la instancia primaria falla, RDS hace failover automático
# a la standby sin intervención manual.

# -------------------------------------------------
# 1. DB Subnet Group - subnets privadas en 2 AZ
# -------------------------------------------------
resource "aws_db_subnet_group" "technova" {
  name        = "subnet-group-${var.proyecto}"
  description = "Subnet group para RDS TechNova (subnets privadas, 2 AZ)"

  subnet_ids = [
    aws_subnet.privada_datos_a.id,
    aws_subnet.privada_datos_b.id,
  ]

  tags = {
    Name = "subnet-group-${var.proyecto}"
  }
}

# -------------------------------------------------
# 2. Instancia RDS MySQL Multi-AZ
# -------------------------------------------------
resource "aws_db_instance" "technova" {
  identifier = "rds-${var.proyecto}"

  # Motor
  engine         = "mysql"
  engine_version = "8.4"

  # Capacidad que pide la EP2: db.t4g.small
  instance_class = var.db_instance_class

  # Almacenamiento: 50 GB gp3 cifrado
  storage_type      = "gp3"
  allocated_storage = 50
  storage_encrypted = true

  # Credenciales
  db_name  = var.db_name
  username = var.db_master_username
  password = var.db_master_password

  # Red - subnets privadas, sin acceso público
  db_subnet_group_name   = aws_db_subnet_group.technova.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # --- ALTA DISPONIBILIDAD ---
  # Multi-AZ crea una réplica standby síncrona en la otra AZ.
  multi_az = true

  # --- RESPALDOS AUTOMÁTICOS ---
  # 7 días de retención. RDS toma un snapshot diario automático.
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false

  # En laboratorio: no exige snapshot final al destruir.
  # En producción se recomienda skip_final_snapshot = false.
  skip_final_snapshot = true

  tags = {
    Name = "rds-${var.proyecto}"
  }
}
