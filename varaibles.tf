variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ExampleAppServerInstance"
}
variable "region" {
  description = "Region to create environment in"
  type        = string
}
variable "profile" {
  description = "AWS profile to use when running"
  type        = string
  default     = "default"
}