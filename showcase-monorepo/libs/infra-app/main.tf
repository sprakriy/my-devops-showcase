terraform {
  backend "s3" {
    bucket       = "sp-01182026-infra-terraform-state"
    key          = "infra-app/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" { region = "us-east-1" }

data "terraform_remote_state" "infra_main" {
  backend = "s3"
  config = {
    bucket = "sp-01182026-infra-terraform-state"
    key    = "infra-main/terraform.tfstate"
    region = "us-east-1"
  }
}

# Security Group for the EC2 Instance
resource "aws_security_group" "app_sg" {
  name   = "app-server-sg"
  vpc_id = data.terraform_remote_state.infra_main.outputs.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For testing; tighten this to your IP for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The EC2 Instance
resource "aws_instance" "app_server" {
  ami           = "ami-0e86e20dae9224db8" # Amazon Linux 2023 in us-east-1
  instance_type = "t3.micro"
  
  # Put it in a Public Subnet so you can SSH to it
  subnet_id                   = data.terraform_remote_state.infra_main.outputs.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  # Script to install psql client on startup
  user_data = <<-EOF
              #!/bin/bash
              sudo dnf update -y
              sudo dnf install -y postgresql15
              EOF

  tags = { Name = "Showcase-App-Server" }
}

# This bridges the gap between the two projects
resource "aws_security_group_rule" "allow_app_to_db" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  
  # The "Destination": The RDS Security Group ID from infra-main
  # Note: You need to add "rds_sg_id" to your infra-main outputs first!
  security_group_id        = data.terraform_remote_state.infra_main.outputs.rds_sg_id
  
  # The "Source": The Security Group we just created in this file
  source_security_group_id = aws_security_group.app_sg.id
}

output "public_ip" {
  value = aws_instance.app_server.public_ip
}