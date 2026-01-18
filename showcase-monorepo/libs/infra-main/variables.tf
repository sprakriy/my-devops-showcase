variable "db_password" {
  description = "The password for the RDS instance"
  type        = string
  sensitive   = true
}