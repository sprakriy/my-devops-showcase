terraform {
  backend "s3" {
    bucket       = "sp-01182026-infra-terraform-state"
    key          = "infra-dns/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

# Get the VPC ID from your other project's state
data "terraform_remote_state" "infra_main" {
  backend = "s3"
  config = {
    bucket = "sp-01182026-infra-terraform-state"
    key    = "infra-main/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_route53_zone" "private" {
  name = "showcase.internal"

  vpc {
    vpc_id = data.terraform_remote_state.infra_main.outputs.vpc_id
  }
}

# Create a CNAME so you have a pretty URL for your DB
resource "aws_route53_record" "database" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.showcase.internal"
  type    = "CNAME"
  ttl     = "300"
  records = [data.terraform_remote_state.infra_main.outputs.db_instance_endpoint]
}