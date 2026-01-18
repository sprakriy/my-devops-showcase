output "vpc_id" {
  value = module.vpc.vpc_id
}

output "db_instance_endpoint" {
  value = split(":", aws_db_instance.postgres.endpoint)[0]
}

output "public_subnets" {
  value = module.vpc.public_subnets
}