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
        Resource = "${aws_cloudwatch_log_group.jenkins_log_group.arn}:*"
      }
    ]
  })
  tags = merge(
    var.additional_tags
  )
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "jenkins-execution-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_ecs_tasks.json
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