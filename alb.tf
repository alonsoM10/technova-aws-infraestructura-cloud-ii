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

  # El ALB vive en las dos subnets públicas (HA)
  subnets = [
    aws_subnet.publica_a.id,
    aws_subnet.publica_b.id,
  ]

  tags = {
    Name = "alb-${var.proyecto}"
  }
}

# -------------------------------------------------
# 2. Target Group - apunta a las EC2 en puerto 80
# -------------------------------------------------
resource "aws_lb_target_group" "technova" {
  name     = "tg-${var.proyecto}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.technova.id

  # Health check: el ALB consulta esta ruta para saber si la
  # instancia está sana. Si falla, deja de enviarle tráfico.
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
# 3. Listener HTTP (puerto 80)
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

# NOTA sobre HTTPS (puerto 443):
# Un listener HTTPS requiere un certificado en AWS Certificate Manager.
# En AWS Academy Learner Lab generalmente NO se puede emitir un
# certificado validado. Por eso se deja solo el listener HTTP.
# Si tu lab permite ACM, descomenta el bloque siguiente y crea el cert:
#
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.technova.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = "arn:aws:acm:us-east-1:...:certificate/..."
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.technova.arn
#   }
# }
