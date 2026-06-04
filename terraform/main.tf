# ==========================================
# VIRTUAL PRIVATE CLOUD (VPC) & NETWORKING
# ==========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "production-vpc"
  cidr = "10.0.0.0/16"

  # Haute Disponibilité : 3 Zones de Disponibilité (AZs)
  azs             = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # Sécurité : Les instances dans les subnets privés accèdent à internet via des NAT Gateways
  enable_nat_gateway = true
  single_nat_gateway = false # Un NAT par AZ pour éliminer le Single Point of Failure (SPOF)
  enable_vpn_gateway = false

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "Core-Platform"
  }
}

# ==========================================
# BASE DE DONNÉES RDS POSTGRESQL (Multi-AZ)
# ==========================================
resource "aws_db_instance" "postgres_production" {
  identifier           = "prod-postgres-db"
  allocated_storage    = 100
  storage_type         = "gp3" # SSD ultra-rapide nouvelle génération
  engine               = "postgres"
  engine_version       = "15.4"
  
  # FinOps & Green IT : Graviton (ARM) pour un meilleur ratio Perf/Watt
  instance_class       = "db.t4g.large" 
  
  username             = "admin_user"
  password             = var.db_password # DevSecOps: Injecté via AWS Secrets Manager en CI/CD
  parameter_group_name = "default.postgres15"
  
  # Bonnes pratiques AWS
  multi_az               = true  # Réplication asynchrone sur une autre AZ pour la résilience
  publicly_accessible    = false # Zero Trust: Accessible uniquement depuis le VPC privé
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  
  storage_encrypted      = true  # Chiffrement KMS At-Rest
  skip_final_snapshot    = false
  backup_retention_period = 7    # Sauvegardes gardées pendant 7 jours
}

# ==========================================
# SECURITY GROUPS (Zero Trust Architecture)
# ==========================================
resource "aws_security_group" "db_sg" {
  name        = "prod-database-sg"
  description = "Autorise uniquement le trafic depuis l'application ECS/EKS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL access from Application Security Group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "prod-application-sg"
  description = "Autorise le trafic entrant depuis l'ALB"
  vpc_id      = module.vpc.vpc_id
  # Les règles d'ingress HTTP(S) seraient configurées ici...
}

variable "db_password" {
  description = "Mot de passe de la DB. Ne jamais coder en dur (Injecté via Jenkins ou Vault)."
  type        = string
  sensitive   = true
}
