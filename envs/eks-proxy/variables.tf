variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "bandi-eks-task"
}

variable "cluster_version" {
  type        = string
  default     = "1.34"
  description = "Kubernetes version. Must be in standard support (extended support costs much more)."
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_count" {
  type    = number
  default = 2
}