# ==========================================
# TERRAFORM BACKEND & STATE MANAGEMENT
# ==========================================
terraform {
  backend "s3" {
    bucket         = "mon-entreprise-tf-state-production"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-3"
    
    # Sécurité : Chiffrement du state
    encrypt        = true
    
    # State Locking : Évite les conflits de déploiement simultanés
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "La région AWS de déploiement"
  default     = "eu-west-3"
}
