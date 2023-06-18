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

data "aws_iam_policy_document" "assume_role_policy_ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "assume_role_policy_ecs_" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "jenkins-execution-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_ecs_tasks.json
  tags = merge(
    var.additional_tags
  )
}

resource "aws_iam_policy" "getEcrImages" {
  name        = "GetJenkinsImage"
  description = "Allows to pull and list images within Jenkins ECR."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:DescribeImageScanFindings",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImageReplicationStatus",
          "ecr:ListTagsForResource",
          "ecr:ListImages",
          "ecr:BatchGetRepositoryScanningConfiguration",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetRepositoryPolicy",
          "ecr:GetLifecyclePolicy"
        ]
        Effect   = "Allow"
        Resource = aws_ecr_repository.jenkins_ecr.arn
      }
    ]
  })
  tags = merge(
    var.additional_tags
  )
}

resource "aws_iam_policy" "write_jenkins_logs" {
  name        = "WriteJenkinsLogStream"
  description = "Allows write into Jenkin's logstream"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = join("", [aws_cloudwatch_log_group.jenkins_log_group.arn, ":*"])
      }
    ]
  })
  tags = merge(
    var.additional_tags
  )
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = aws_iam_policy.getEcrImages.arn
}

resource "aws_iam_role_policy_attachment" "writeLogGroup_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = aws_iam_policy.write_jenkins_logs.arn
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

resource "aws_efs_file_system" "jenkins_fs" {
  encrypted = true

  tags = merge(
    var.additional_tags
  )
}

resource "aws_efs_access_point" "jenkins_fs_ap" {
  file_system_id = aws_efs_file_system.jenkins_fs.id
  root_directory {
    path = "/jenkins"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 755
    }
  }

  tags = merge(
    var.additional_tags
  )
}

resource "aws_efs_mount_target" "mount_targets" {
  for_each        = toset(data.aws_subnets.jenkins_subnets.ids)
  file_system_id  = aws_efs_file_system.jenkins_fs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]
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
  //task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
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

resource "aws_security_group" "efs_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port        = 2049
    to_port          = 2049
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
  depends_on = [aws_efs_mount_target.mount_targets]
  tags = merge(
    var.additional_tags
  )
}