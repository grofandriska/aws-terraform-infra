variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "target_group_arns" {
  type = list(string)
}

variable "lb_security_group_id" {
  type        = string
  description = "A load balancer security groupja; csak ez érheti el a gépeket a 80-as porton."
}

variable "iam_instance_profile_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  type    = string
  default = ""
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}