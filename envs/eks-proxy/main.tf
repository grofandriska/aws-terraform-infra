provider "aws" {
    region = var.region

    default_tags {
      tags = {
        Project =var.project_name
        ManagedBy ="terraform"
      }
    }
}

module "infra" {
    source = "../../modules/infra"
    project_name = var.project_name
}

resource "aws_eip" "nat" {
    domain = "vpc"

    tags = {
        Name = "${var.project_name}-nat-eip"
    }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

