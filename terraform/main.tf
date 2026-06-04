# ==========================================
# VIRTUAL PRIVATE CLOUD (VPC) & NETWORKING
# ==========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  name = "production-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false
  enable_vpn_gateway = false
}

# ==========================================
# IAM ROLES FOR SERVICE ACCOUNTS (IRSA) - Securité Zero Trust
# ==========================================
# Permet au Pod Kubernetes (EKS) d'accéder à S3 SANS clés d'accès codées en dur !
module "iam_eks_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "prod-app-s3-access-role"
  
  attach_s3_readwrite_policy = true
  
  oidc_providers = {
    main = {
      # provider_arn               = module.eks.oidc_provider_arn
      # namespace_service_accounts = ["default:app-service-account"]
    }
  }
}

# ==========================================
# AMAZON RDS POSTGRESQL (Graviton - ARM Architecture)
# ==========================================
resource "aws_db_instance" "postgres" {
  identifier           = "prod-postgres-db"
  allocated_storage    = 100
  storage_type         = "gp3" # SSD IOPS provisionnés - Performance constante
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t4g.large" # AWS Graviton (Processeur ARM: Moins énergivore = Green IT & FinOps)
  username             = "admin_user"
  password             = var.db_password # Transmis via Secrets Manager
  parameter_group_name = "default.postgres15"
  
  multi_az               = true  # Failover automatique vers une autre Availability Zone
  publicly_accessible    = false # Isolation réseau stricte
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  storage_encrypted      = true  # KMS Encryption at rest (Norme sécurité entreprise)
}

# ==========================================
# SECURITY GROUPS (Règles de Firewall Cloud)
# ==========================================
resource "aws_security_group" "db_sg" {
  name        = "prod-db-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # Autorise UNIQUEMENT le flux provenant des instances du LoadBalancer/App
    security_groups = [aws_security_group.app_sg.id]
  }
}

resource "aws_security_group" "app_sg" {
  name   = "prod-app-sg"
  vpc_id = module.vpc.vpc_id
}
