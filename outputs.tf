output "repository_url" {
  description = "The ECR repository url"
  value       = aws_ecr_repository.jenkins_ecr.repository_url
}

output "alb_url" {
  description = "The jenkins alb url"
  value       = aws_alb.application_load_balancer.dns_name
}
