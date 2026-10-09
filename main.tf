provider "aws" {
  region  = "eu-central-1"
  profile = "az-en-profilom"
}

# 1. Alap infrastruktúra (Default VPC és Subnetek lekérdezése)
module "infra" {
  source = "./modules/infra"
}

# 2. Load Balancer (ALB, Target Group, Security Group)
module "loadbalance" {
  source     = "./modules/load-balancer"
  vpc_id     = module.infra.vpc_id
  subnet_ids = module.infra.subnet_ids
}

# 3. IAM & SSM (Biztonságos, kulcsnélküli távoli eléréshez)
module "iam" {
  source = "./modules/iam-ssm"
}

# 4. Compute & ASG (Launch Template, ASG, Ubuntu AMI)
module "instances" {
  source                    = "./modules/compute-asg"
  vpc_id                    = module.infra.vpc_id
  subnet_ids                = module.infra.subnet_ids
  target_group_arns         = [module.loadbalance.target_group_arn]
  iam_instance_profile_name = module.iam.instance_profile_name
  
  # Értékek átadása a tfvars / gyökér változókból
  instance_type             = var.instance_type
  ami_id                    = var.ami_id
}