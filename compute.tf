# ──────────────────────────────────────────────
# COMPUTE - Launch Template + Auto Scaling Group
# ──────────────────────────────────────────────
# Núcleo de la Alta Disponibilidad a nivel de cómputo.
# El ASG mantiene siempre 2 instancias vivas (mín 2 / máx 3)
# repartidas en 2 AZ. Si una cae, el ASG la reconstruye sola.

# -------------------------------------------------
# 0. Búsqueda automática de la AMI base
# -------------------------------------------------
# Terraform consulta a AWS y toma la ÚLTIMA versión de
# Amazon Linux 2023. Así no hay que crear ni copiar una AMI
# a mano. El user_data se encarga de instalar Nginx al arrancar.
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
# El user_data instala Nginx y publica la web en cada instancia.
resource "aws_launch_template" "technova" {
  name          = "lt-${var.proyecto}"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  # Volumen raíz: 50 GB gp3 cifrado (lo que pide la EP2)
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
  # Se codifica en base64 desde el archivo externo user_data.sh.
  user_data = base64encode(file("${path.module}/user_data.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ec2-${var.proyecto}-asg"
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

  # Capacidad que pide la EP2: min 2, deseado 2, máximo 3
  min_size         = 2
  desired_capacity = 2
  max_size         = 3

  # Instancias repartidas en las 2 subnets públicas (2 AZ)
  vpc_zone_identifier = [
    aws_subnet.publica_a.id,
    aws_subnet.publica_b.id,
  ]

  # Conecta el ASG con el target group del ALB
  target_group_arns = [aws_lb_target_group.technova.arn]

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
# instancia (hasta el máximo de 3). Cuando baja, la retira.
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
