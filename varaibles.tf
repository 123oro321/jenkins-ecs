variable "vpc_id" {
  description = "AWS vpc id for jenkins"
  type        = string
}
variable "additional_tags" {
  default     = { app : "jenkins" }
  description = "Additional resource tags"
  type        = map(string)
}