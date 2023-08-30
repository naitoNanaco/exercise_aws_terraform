locals {
  name                  = "test_app"
  environment           = "test"
  vpc_cidr              = "10.0.0.0/16"
  subnet_cidr_public_a  = "10.0.1.0/24"
  subnet_cidr_public_c  = "10.0.2.0/24"
  subnet_cidr_private_a = "10.0.3.0/24"
  subnet_cidr_private_c = "10.0.4.0/24"
  allowed_ips = [
    "${trimspace(data.http.myip.response_body)}/32",
  ]
  tags = {
    Service     = local.name
    Environment = local.environment
  }
}

data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "current" {}
data "aws_region" "current" {}
data "http" "myip" {
  url = "https://checkip.amazonaws.com/"
}