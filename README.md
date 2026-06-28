# TechNova HA - Infraestructura en Terraform

Proyecto Terraform para la Evaluación Parcial N°2 de Infraestructura Cloud II
(ARY1101). Despliega la arquitectura de **Alta Disponibilidad** del caso
TechNova Solutions sobre AWS.

## Qué despliega

| Capa        | Recurso                                                        |
|-------------|----------------------------------------------------------------|
| Red         | VPC, 4 subnets (2 públicas + 2 privadas) en **2 AZ**, IGW, rutas |
| Seguridad   | 3 Security Groups por capa: ALB → EC2 → RDS                    |
| Balanceo    | Application Load Balancer + Target Group + Listener HTTP       |
| Cómputo     | Launch Template + Auto Scaling Group (mín 2 / des 2 / máx 3)   |
| Base datos  | RDS MySQL 8.4 **Multi-AZ** con backups automáticos (7 días)    |
| Monitoreo   | CloudWatch: dashboard, alarmas CPU/Memoria/RDS, tema SNS       |
| Respaldo    | AWS Backup: bóveda + plan diario para EC2 y RDS                |

## Archivos

```
technova-ha/
├── provider.tf      Provider AWS y versión de Terraform
├── variables.tf     Variables configurables
├── vpc.tf           VPC, subnets, IGW, route tables
├── security.tf      Security Groups (ALB, EC2, RDS)
├── alb.tf           Load Balancer, target group, listener
├── compute.tf       Launch Template y Auto Scaling Group
├── user_data.sh     Script de arranque de las EC2
├── rds.tf           RDS MySQL Multi-AZ
├── monitoring.tf    CloudWatch + SNS
├── backup.tf        AWS Backup
├── outputs.tf       Valores de salida
└── terraform.tfvars.ejemplo   Plantilla de variables
```

## Requisitos previos

1. **Terraform** instalado (>= 1.5).
2. **Credenciales de AWS Academy**: en el Learner Lab, abre "AWS Details" y
   copia las credenciales. Pégalas en `~/.aws/credentials` o expórtalas:
   ```bash
   export AWS_ACCESS_KEY_ID=...
   export AWS_SECRET_ACCESS_KEY=...
   export AWS_SESSION_TOKEN=...
   ```
   Estas credenciales **rotan cada sesión**: hay que actualizarlas al volver.
3. **Crear la AMI**: en la consola EC2, selecciona tu instancia original de
   TechNova → Actions → Image and templates → Create image. Cuando quede
   en estado "available", copia el ID (`ami-xxxx`).

## Cómo desplegar

```bash
# 1. Copiar y completar las variables
cp terraform.tfvars.ejemplo terraform.tfvars
#    editar terraform.tfvars: mi_ip, ami_id, db_master_password, email_alertas

# 2. Inicializar Terraform (descarga el provider)
terraform init

# 3. Revisar el plan (qué va a crear)
terraform plan

# 4. Aplicar (crear la infraestructura)
terraform apply

# 5. Al terminar, ver los datos de acceso
terraform output
```

Abre la URL del output `alb_dns` en el navegador para ver la aplicación.

## Pruebas para la evaluación (rúbrica)

- **HA de cómputo (IE1.7)**: termina una instancia EC2 desde la consola.
  El ALB deja de enviarle tráfico y el ASG levanta una nueva en minutos.
- **HA de base de datos**: en RDS → Actions → Reboot → marca "Reboot with
  failover". La standby pasa a primaria.
- **Monitoreo (IE1.4)**: genera carga de CPU en una EC2 (con el script de
  rendimiento del AVA) hasta superar el 70%. La alarma se dispara y llega
  el correo por SNS.
- **Respaldo y restore (IE1.6)**: en AWS Backup, lanza un backup on-demand
  y luego restaura RDS/EC2 desde la bóveda.

## Para destruir todo

```bash
terraform destroy
```

## Nota sobre AWS Academy Learner Lab

- El Learner Lab suele **bloquear la creación de roles IAM**. Si
  `terraform apply` falla en el recurso `aws_iam_role.backup`, reemplázalo
  por el rol preexistente **LabRole**: borra los recursos `aws_iam_role` y
  `aws_iam_role_policy_attachment` de `backup.tf` y en `aws_backup_selection`
  usa:
  ```hcl
  iam_role_arn = "arn:aws:iam::TU_ID_CUENTA:role/LabRole"
  ```
- El listener HTTPS (443) requiere un certificado ACM, que el lab no suele
  permitir. Por eso solo se configura el listener HTTP (80).
- Conserva el archivo `terraform.tfstate` entre sesiones: es el registro de
  lo que Terraform creó.
