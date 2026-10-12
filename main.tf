provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

module "infra" {
  source       = "./modules/infra"
  project_name = var.project_name
}

module "loadbalance" {
  source       = "./modules/lb"
  project_name = var.project_name
  vpc_id       = module.infra.vpc_id
  subnet_ids   = module.infra.subnet_ids
}

module "iam" {
  source = "./modules/iam-ssm"
}

module "instances" {
  source                    = "./modules/asg"
  project_name              = var.project_name
  vpc_id                    = module.infra.vpc_id
  subnet_ids                = module.infra.subnet_ids
  target_group_arns         = [module.loadbalance.target_group_arn]
  lb_security_group_id      = module.loadbalance.lb_security_group_id
  iam_instance_profile_name = module.iam.instance_profile_name

  instance_type = var.instance_type
  ami_id        = var.ami_id
}