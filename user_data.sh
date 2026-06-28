#!/bin/bash
# ──────────────────────────────────────────────
# USER DATA - Se ejecuta al arrancar cada instancia EC2
# ──────────────────────────────────────────────
# Sin Docker: la app es una pagina web simple servida con Nginx.
# 1. Instala y arranca Nginx
# 2. Publica una pagina de prueba (identifica la instancia)
# 3. Instala y configura el CloudWatch Agent (memoria + disco)

exec > /var/log/user-data.log 2>&1
set -x

# --- 1. Instalar y arrancar Nginx ---
yum update -y
yum install -y nginx
systemctl enable nginx
systemctl start nginx

# --- 2. Publicar la pagina web ---
# Pagina simple que muestra el ID de la instancia y su AZ.
# Esto sirve como EVIDENCIA en la prueba de HA: al recargar
# el navegador veras como el ALB alterna entre instancias.
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>TechNova Solutions</title>
  <style>
    body { font-family: Arial, sans-serif; text-align: center; margin-top: 80px; }
    .card { display: inline-block; padding: 40px; border: 2px solid #f4b400;
            border-radius: 12px; }
    h1 { color: #333; }
    .dato { color: #1a73e8; font-weight: bold; }
  </style>
</head>
<body>
  <div class="card">
    <h1>TechNova Solutions - Alta Disponibilidad</h1>
    <p>Aplicacion web servida por Nginx en AWS</p>
    <p>Instancia: <span class="dato">$INSTANCE_ID</span></p>
    <p>Zona de disponibilidad: <span class="dato">$AZ</span></p>
  </div>
</body>
</html>
EOF

# --- 3. Instalar el CloudWatch Agent ---
# Permite enviar metricas de MEMORIA y DISCO, que EC2 no
# reporta de forma nativa (solo CPU y red por defecto).
yum install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'EOF'
{
  "metrics": {
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          { "name": "mem_used_percent", "rename": "MemoriaUsadaPorcentaje" }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          { "name": "used_percent", "rename": "DiscoUsadoPorcentaje" }
        ],
        "resources": ["/"],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Arrancar el agente con esa configuracion
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json \
  -s

echo "User data finalizado correctamente"
