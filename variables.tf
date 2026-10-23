variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "project_name" {
  type        = string
  default     = "auto-scale-infra"
  description = "Előtag minden erőforrás nevéhez, hogy a közös fiókban ne ütközzön."

  validation {
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.project_name))
    error_message = "A project_name csak kisbetűt, számot és kötőjelet tartalmazhat, max. 20 karakter."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  type        = string
  default     = ""
  description = "Egyedi AMI. Ha üres, a legfrissebb Ubuntu 22.04."
}