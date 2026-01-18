terraform {
  backend "s3" {
    bucket         = "sp-01182026-infra-terraform-state"
    key            = "infra-main/terraform.tfstate" # This keeps main separate from bootstrap
    region         = "us-east-1"
    use_lockfile   = true   # Using the modern S3 locking we just discovered
    encrypt        = true
  }
}# 1. The Network (VPC)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "showcase-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false # Keeping costs low for now
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# 2. Database Security Group (The "Bouncer")
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # Only allow traffic from inside the VPC
  }
}
resource "aws_db_subnet_group" "postgres_subnet_group" {
  name       = "showcase-db-subnet-group"
  subnet_ids = module.vpc.private_subnets # This forces it into our private subnets

  tags = {
    Name = "My DB subnet group"
  }
}

# 3. The RDS Instance (Postgres)
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  db_name              = "showcase_db"
  username             = "dbadmin"
  password             = var.db_password
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  db_subnet_group_name   = aws_db_subnet_group.postgres_subnet_group.name # Use the resource abo
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}


output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}
