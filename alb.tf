# ──────────────────────────────────────────────
# ALB - Application Load Balancer (Alta Disponibilidad)
# ──────────────────────────────────────────────
# Distribuye el tráfico entre las instancias EC2 del Auto Scaling
# Group repartidas en las dos AZ. Si una instancia o una AZ cae,
# el ALB envía el tráfico a las instancias sanas.

# -------------------------------------------------
# 1. Application Load Balancer
# -------------------------------------------------
resource "aws_lb" "technova" {
  name               = "alb-${var.proyecto}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.publica_a.id,
    aws_subnet.publica_b.id,
  ]

  tags = {
    Name = "alb-${var.proyecto}"
  }
}

# -------------------------------------------------
# 2. Target Group FRONTEND - EC2 en puerto 80 (Nginx)
# -------------------------------------------------
resource "aws_lb_target_group" "technova" {
  name     = "tg-${var.proyecto}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.technova.id

  # El health check consulta "/" del frontend. Si responde 200,
  # la instancia está sana y el ALB le envía tráfico.
  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "tg-${var.proyecto}"
  }
}

# -------------------------------------------------
# 3. Target Group BACKEND - EC2 en puerto 3001 (API Node)
# -------------------------------------------------
# El frontend llama a la API por el puerto 3001. Este target group
# permite que el ALB enrute también ese tráfico a las instancias.
resource "aws_lb_target_group" "backend" {
  name     = "tg-${var.proyecto}-api"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.technova.id

  # La API expone /api/health -> ideal para el health check.
  health_check {
    enabled             = true
    path                = "/api/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "tg-${var.proyecto}-api"
  }
}

# -------------------------------------------------
# 4. Listener HTTP (puerto 80) -> frontend
# -------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.technova.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.technova.arn
  }
}

# -------------------------------------------------
# 5. Listener HTTP (puerto 3001) -> backend/API
# -------------------------------------------------
resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.technova.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Conecta el ASG con AMBOS target groups (frontend + backend).
# Esto reemplaza el target_group_arns simple de compute.tf.
resource "aws_autoscaling_attachment" "frontend" {
  autoscaling_group_name = aws_autoscaling_group.technova.name
  lb_target_group_arn    = aws_lb_target_group.technova.arn
}

resource "aws_autoscaling_attachment" "backend" {
  autoscaling_group_name = aws_autoscaling_group.technova.name
  lb_target_group_arn    = aws_lb_target_group.backend.arn
}

# NOTA sobre HTTPS (443): requiere certificado ACM que el
# Learner Lab normalmente no permite emitir. Se deja solo HTTP.