output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.subnet_public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.subnet_private[*].id
}