# ──────────────────────────────────────────────
# VARIABLES - Parámetros configurables del proyecto
# ──────────────────────────────────────────────

variable "aws_region" {
  description = "Región de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "proyecto" {
  description = "Nombre base del proyecto, usado como prefijo en los recursos"
  type        = string
  default     = "technova"
}

# --- Red ---
variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/22"
}

variable "az_a" {
  description = "Primera zona de disponibilidad"
  type        = string
  default     = "us-east-1a"
}

variable "az_b" {
  description = "Segunda zona de disponibilidad (para HA)"
  type        = string
  default     = "us-east-1b"
}

# --- Acceso ---
variable "mi_ip" {
  description = "Tu IP pública en formato CIDR para acceso SSH (ej. 200.10.20.30/32)"
  type        = string
  # Obtén tu IP con: curl -s https://checkip.amazonaws.com
}

variable "key_name" {
  description = "Nombre del key pair para SSH a las instancias EC2"
  type        = string
  default     = "vockey"
}

# --- Cómputo ---
variable "instance_type" {
  description = "Tipo de instancia EC2 (la EP2 pide t3.small)"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  # NOTA: variable en desuso. compute.tf busca la AMI de
  # Amazon Linux 2023 automáticamente con un data source.
  # Se conserva el bloque vacío de referencia, pero no es
  # obligatorio. Si quieres, puedes borrar este bloque.
  description = "(En desuso) ID de AMI - ahora se detecta automáticamente"
  type        = string
  default     = ""
}

# --- Base de datos ---
variable "db_instance_class" {
  description = "Clase de instancia RDS (la EP2 pide db.t4g.small)"
  type        = string
  default     = "db.t4g.small"
}

variable "db_master_username" {
  description = "Usuario maestro de RDS"
  type        = string
  default     = "admin"
}

variable "db_master_password" {
  description = "Contraseña del usuario maestro de RDS"
  type        = string
  sensitive   = true
  # Pásala por terraform.tfvars o por -var, NUNCA la dejes en el código.
}

variable "db_name" {
  description = "Nombre de la base de datos inicial"
  type        = string
  default     = "tienda_tecnologica"
}

# --- Monitoreo ---
variable "email_alertas" {
  description = "Correo que recibirá las notificaciones SNS de las alarmas"
  type        = string
  # Recibirás un correo de confirmación de suscripción que debes aceptar.
}

variable "umbral_cpu" {
  description = "Umbral de CPU (%) para disparar la alarma"
  type        = number
  default     = 70
}

variable "umbral_memoria" {
  description = "Umbral de memoria (%) para disparar la alarma"
  type        = number
  default     = 70
}
# ──────────────────────────────────────────────
# VARIABLES EXTRA - agrégalas a tu variables.tf existente
# ──────────────────────────────────────────────

# --- Perfil de instancia (rol IAM para SSM + ECR) ---
variable "instance_profile_name" {
  description = "Perfil de instancia con permisos SSM y ECR. En AWS Academy: LabInstanceProfile"
  type        = string
  default     = "LabInstanceProfile"
}

# --- Credenciales de la APP dentro de la base de datos ---
# Son distintas del usuario maestro de RDS (admin). La app se
# conecta con este usuario, que se crea al cargar el init.sql.
variable "db_app_user" {
  description = "Usuario de aplicacion dentro de MySQL (lo crea init.sql)"
  type        = string
  default     = "alumno"
}

variable "db_app_password" {
  description = "Password del usuario de aplicacion"
  type        = string
  sensitive   = true
  default     = "alumno123"
}