#!/bin/bash
# ──────────────────────────────────────────────
# USER DATA - Se ejecuta al arrancar cada instancia EC2
# ──────────────────────────────────────────────
# 1. Instala Docker + Docker Compose
# 2. Login a ECR y baja las imagenes frontend + backend
# 3. Levanta la app con docker compose (env_file .env -> RDS)
# 4. Instala y configura el CloudWatch Agent (memoria + disco)
#
# Terraform inyecta: account_id, aws_region, ecr_frontend,
# ecr_backend, rds_endpoint, db_app_user, db_app_pass, db_app_name.

exec > /var/log/user-data.log 2>&1
set -x

# --- 1. Instalar Docker ---
dnf update -y
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

dnf install -y mariadb105

# --- 2. Login a ECR ---
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${aws_region}.amazonaws.com

# --- 3. Desplegar la app ---
mkdir -p /opt/technova

# .env con la config de la base (lo leera el contenedor via env_file)
cat > /opt/technova/.env << EOF
DB_HOST=${rds_endpoint}
DB_USER=${db_app_user}
DB_PASSWORD=${db_app_pass}
DB_NAME=${db_app_name}
DB_PORT=3306
EOF

# docker-compose: usa env_file (NO interpolacion) para que las
# variables lleguen al contenedor. Este fue el bug que dejaba
# DB_HOST vacio.
cat > /opt/technova/docker-compose.yml << EOF
services:
  frontend:
    image: ${ecr_frontend}:latest
    container_name: technova-frontend
    restart: always
    ports:
      - "80:80"
    depends_on:
      - backend

  backend:
    image: ${ecr_backend}:latest
    container_name: technova-backend
    restart: always
    env_file:
      - .env
    ports:
      - "3001:3001"
EOF

cd /opt/technova
docker compose --env-file .env up -d

# --- 4. CloudWatch Agent ---
dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CWEOF'
{
  "metrics": {
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
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
CWEOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json \
  -s

echo "User data finalizado correctamente"