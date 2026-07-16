# ──────────────────────────────────────────────
# COMPUTE - Launch Template + Auto Scaling Group
# ──────────────────────────────────────────────
# Núcleo de la Alta Disponibilidad a nivel de cómputo.
# El ASG mantiene siempre 2 instancias vivas (mín 2 / máx 4)
# repartidas en 2 AZ. Si una cae, el ASG la reconstruye sola.

# -------------------------------------------------
# 0. Búsqueda automática de la AMI base
# -------------------------------------------------
# Terraform consulta a AWS y toma la ÚLTIMA versión de
# Amazon Linux 2023. Así no hay que crear ni copiar una AMI
# a mano. El user_data se encarga de instalar todo al arrancar.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -------------------------------------------------
# 1. Launch Template - "molde" de las instancias EC2
# -------------------------------------------------
# El user_data instala Docker, hace login a ECR, baja las
# imágenes de la app (frontend + backend) y las levanta con
# docker compose apuntando a RDS. También instala el CW Agent.
resource "aws_launch_template" "technova" {
  name          = "lt-${var.proyecto}"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  # --- Rol de instancia para SSM + acceso a ECR ---
  # En AWS Academy se usa el perfil preexistente LabInstanceProfile,
  # que ya trae permisos de SSM y de lectura de ECR. Esto cubre el
  # indicador "Access Control: Rol EC2 para SSM".
  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Volumen raíz: 50 GB gp3 CIFRADO (lo que pide la pauta)
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  # User Data: arranca la app y el CloudWatch Agent al iniciar.
  # Se renderiza desde una plantilla para inyectar variables
  # (cuenta, región, endpoint de RDS, credenciales de la app).
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    account_id   = data.aws_caller_identity.current.account_id
    aws_region   = var.aws_region
    ecr_frontend = aws_ecr_repository.frontend.repository_url
    ecr_backend  = aws_ecr_repository.backend.repository_url
    rds_endpoint = aws_db_instance.technova.address
    db_app_user  = var.db_app_user
    db_app_pass  = var.db_app_password
    db_app_name  = var.db_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name     = "ec2-${var.proyecto}-asg"
      Proyecto = "TechNova"
    }
  }

  tags = {
    Name = "lt-${var.proyecto}"
  }
}

# -------------------------------------------------
# 2. Auto Scaling Group
# -------------------------------------------------
resource "aws_autoscaling_group" "technova" {
  name = "asg-${var.proyecto}"

  # Capacidad que pide la pauta EFT: min 2, deseado 2, MÁXIMO 4
  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  # Instancias repartidas en las 2 subnets públicas (2 AZ)
  vpc_zone_identifier = [
    aws_subnet.publica_a.id,
    aws_subnet.publica_b.id,
  ]

  # La conexión con los target groups (frontend 80 y backend 3001)
  # se hace con aws_autoscaling_attachment en alb.tf, para poder
  # enganchar los DOS target groups sin conflicto.

  # Usa el health check del ELB: si el ALB marca una instancia
  # como unhealthy, el ASG la reemplaza automáticamente.
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.technova.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ec2-${var.proyecto}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Proyecto"
    value               = "TechNova"
    propagate_at_launch = true
  }
}

# -------------------------------------------------
# 3. Política de escalamiento por CPU (target tracking)
# -------------------------------------------------
# Si el promedio de CPU supera el 60%, el ASG agrega una
# instancia (hasta el máximo de 4). Cuando baja, la retira.
# Esto es lo que dispara el escalado durante la prueba de estrés.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "policy-cpu-${var.proyecto}"
  autoscaling_group_name = aws_autoscaling_group.technova.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}