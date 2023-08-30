# ECS Cluster
resource "aws_ecs_cluster" "test_app" {
  name = local.name

  tags = merge(
    {
      Name = "${local.name}_ecs"
    },
    local.tags,
  )
}

resource "aws_ecs_cluster_capacity_providers" "test_app" {
  cluster_name       = aws_ecs_cluster.test_app.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 0
    weight            = 100
  }
}

# Target Group
resource "aws_lb_target_group" "test_app" {
  name                 = "${local.name}-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 60

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    port                = 80
    protocol            = "HTTP"
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(
    {
      Name = "${local.name}_target_group"
    },
    local.tags,
  )
}

# ALB
resource "aws_lb" "test_app" {
  name                       = local.name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.public_a.id]
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_log_test_app.id
    enabled = true
  }

  tags = merge(
    {
      Name = "${local.name}_alb"
    },
    local.tags,
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.test_app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = merge(
    {
      Name = "${local.name}_alb_listner_http"
    },
    local.tags,
  )
}

resource "aws_lb_listener_rule" "forward_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10000

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test_app.arn
  }

  condition {
    host_header {
      values = [aws_lb.test_app.dns_name]
    }
  }

  depends_on = [aws_lb.test_app]
}

resource "aws_s3_bucket" "alb_log_test_app" {
  bucket = "${local.name}_${local.environment}_alb_log"

  force_destroy = true

  tags = merge(
    {
      Name = "${local.name}_alb_log_bucket"
    },
    local.tags,
  )
}

resource "aws_s3_bucket_policy" "alb_log_test_app" {
  bucket = aws_s3_bucket.alb_log_test_app.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_elb_service_account.current.arn}"
      },
      "Action": "s3:PutObject",
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.alb_log_test_app.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.alb_log_test_app.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      ],
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.alb_log_test_app.id}"
    }
  ]
}
EOF
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_log_test_app" {
  bucket = aws_s3_bucket.alb_log_test_app.id
  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_log_test_app" {
  bucket = aws_s3_bucket.alb_log_test_app.bucket

  rule {
    id = "log"

    expiration {
      days = 90
    }

    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# Log Stream
resource "aws_cloudwatch_log_group" "test_app" {
  name              = "logs/ecs/${local.name}"
  retention_in_days = 30
}

# Task Definition
resource "aws_ecs_task_definition" "test_app" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "bridge"
  cpu                      = 256
  memory                   = 512
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name              = "app"
      image             = "public.ecr.aws/nginx/nginx:stable"
      cpu               = 256
      memoryReservation = 512
      essential         = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "app"
          awslogs-group         = aws_cloudwatch_log_group.test_app.name
        },
      },
      secrets = [
        {
          name      = "TEST_SECRET_KEY",
          valueFrom = aws_secretsmanager_secret.test_app_keys.arn
        }
      ],
    },
  ])

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [ap-northeast-1a, ap-northeast-1c]"
  }

  tags = merge(
    {
      Name = "${local.name}_task_definition"
    },
    local.tags,
  )
}

# Service
resource "aws_ecs_service" "test_app" {
  name                               = "test_app"
  cluster                            = aws_ecs_cluster.test_app.id
  task_definition                    = aws_ecs_task_definition.test_app.arn
  desired_count                      = 1
  platform_version                   = "LATEST"
  scheduling_strategy                = "REPLICA"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  load_balancer {
    target_group_arn = aws_lb_target_group.test_app.arn
    container_name   = "app"
    container_port   = 80
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 0
    weight            = 100
  }

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_c.id,
    ]
    security_groups = [
      aws_security_group.to_all.id,
    ]
    assign_public_ip = false
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [ap-northeast-1a, ap-northeast-1c]"
  }

  tags = merge(
    {
      Name = "${local.name}_service"
    },
    local.tags,
  )
}
