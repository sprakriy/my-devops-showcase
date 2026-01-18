# infra/bootstrap/main.tf
terraform {
backend "s3" {
    # 1. Where the file lives
    bucket         = "sp-01182026-infra-terraform-state" 
    key            = "infra-bootstrap/terraform.tfstate"
    region         = "us-east-1"
    
    # 2. Where the lock happens (The part I missed)
    #dynamodb_table = "terraform-state-locking" 
    use_lockfile  = true

    # 3. Security
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
resource "aws_s3_bucket" "terraform_state" {
  bucket = "sp-01182026-infra-terraform-state"
  # ... other settings ...
  lifecycle {
    prevent_destroy = true # Safety: Prevents accidental 'terraform destroy' of the brain
  }
}

# The "Safety Net"
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
provider "aws" {
  region = "us-east-1"
}

# 1. The Global State Bucket (The "Garage")
resource "aws_s3_bucket" "state" {
  bucket = "showcase-terraform-state-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# 2. OIDC Provider - The "Trust" between GitHub and AWS
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"] 
}

# 3. The IAM Role GitHub will use
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity",
      Effect = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USER/YOUR_REPO_NAME:*"
        }
      }
    }]
  })
}

# 4. Attach Administrator Access (for the showcase)
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy" "terraform_state_access" {
  name = "TerraformStateAccess"
  #role = aws_iam_role.github_oidc_role.id
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3 Permissions
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
        Resource = ["arn:aws:s3:::sp-01182026-infra-terraform-state", "arn:aws:s3:::sp-01182026-infra-terraform-state/*"]
      },
      {
        # DynamoDB Permissions (The second part of the link)
        Effect   = "Allow"
        Action   = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:319310747432:table/terraform-state-locking"
      }
    ]
  })
}
output "role_arn" {
  value = aws_iam_role.github_actions.arn
}
