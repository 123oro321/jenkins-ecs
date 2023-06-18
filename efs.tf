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