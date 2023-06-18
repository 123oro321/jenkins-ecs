output "repository_url" {
  description = "The ECR repository url"
  value       = aws_ecr_repository.jenkins_ecr.repository_url
}
