output "vpc_id" {
  value = data.aws_vpc.this.id
}

##output "subnet_ids" {
##  value = data.aws_subnets.default.ids
##}