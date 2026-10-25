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

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.infra.vpc_id
  subnet_ids = module.infra.private_subnet_ids

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]

      min_size     = 1
      max_size     = 3
      desired_size = var.node_count

      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }
}