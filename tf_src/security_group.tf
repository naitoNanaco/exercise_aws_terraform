# ALB
resource "aws_security_group" "alb" {
  name   = "${local.name}_alb"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = local.allowed_ips
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "allow_to_app" {
  type      = "egress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"
  cidr_blocks = [
    aws_subnet.private_a.cidr_block,
    aws_subnet.private_c.cidr_block,
  ]
  security_group_id = aws_security_group.alb.id
}

# Egress All
resource "aws_security_group" "to_all" {
  name   = "${local.name}_to_all"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "to_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.to_all.id
}

# from ALB
resource "aws_security_group" "from_alb" {
  name   = "${local.name}_from_alb"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "allow_http_from_alb_app_a" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.from_alb.id
}
