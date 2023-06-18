terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.54"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {}
}

provider "aws" {}

data "aws_region" "current" {}

data "aws_subnets" "jenkins_subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_ecr_repository" "jenkins_ecr" {
  name         = "jenkins"
  force_delete = true
  tags = merge(
    var.additional_tags
  )
}

resource "aws_ecs_cluster" "jenkins_ecs_cluster" {
  name = "JenkinsCluster"
  tags = merge(
    var.additional_tags
  )
}

resource "aws_ecs_cluster_capacity_providers" "jenkins_ecs_cluster_fargate" {
  cluster_name       = aws_ecs_cluster.jenkins_ecs_cluster.name
  capacity_providers = ["FARGATE"]
}

resource "aws_cloudwatch_log_group" "jenkins_log_group" {
  name = "jenkins-logs"
  tags = merge(
    var.additional_tags
  )
}

resource "aws_ecs_task_definition" "jenkins_master_task" {
  family                   = "jenkins"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024 * 2
  memory                   = 1024 * 4
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  container_definitions = jsonencode([
    {
      name      = "jenkins-server"
      image     = "jenkins/jenkins:2.401.1"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      mountPoints = [
        {
          containerPath = "/var/jenkins_home"
          sourceVolume  = "jenkins-data"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.jenkins_log_group.id
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "jenkins-logs"
        }
      }
    }
  ])

  volume {
    name = "jenkins-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.jenkins_fs.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.jenkins_fs_ap.id
      }
    }
  }
  network_mode = "awsvpc"
  tags = merge(
    var.additional_tags
  )
}

resource "aws_security_group" "jenkins_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = merge(
    var.additional_tags
  )
}

resource "aws_ecs_service" "jenkins_service" {
  name                               = "Jenkins_server"
  cluster                            = aws_ecs_cluster.jenkins_ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.jenkins_master_task.arn
  desired_count                      = 1
  scheduling_strategy                = "REPLICA"
  launch_type                        = "FARGATE"
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
  network_configuration {
    subnets          = data.aws_subnets.jenkins_subnets.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.jenkins_sg.id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.target_group.arn
    container_name   = "jenkins-server"
    container_port   = 8080
  }
  depends_on = [aws_efs_mount_target.mount_targets]
  tags = merge(
    var.additional_tags
  )
}

resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = var.vpc_id

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = merge(
    var.additional_tags
  )
}

resource "aws_alb_target_group" "target_group" {
  name        = "jenkins-target"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = 3
    interval            = 300
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/login"
    unhealthy_threshold = "2"
  }

  tags = merge(
    var.additional_tags
  )
}

resource "aws_alb" "application_load_balancer" {
  name               = "jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.jenkins_subnets.ids
  security_groups    = [aws_security_group.load_balancer_security_group.id]
  tags = merge(
    var.additional_tags
  )
}

resource "aws_alb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.id
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group.id
  }
}