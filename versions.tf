terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # ellenőrizd a .terraform.lock.hcl-ben; ha 5.x van ott, írd "~> 5.0"-ra
    }
  }
}