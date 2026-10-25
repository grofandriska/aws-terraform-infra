data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block = cidrsubnet(var.cidr_block,8,count.index) 
  map_public_ip_on_launch = false
  
  vpc_id = aws_vpc.this.id
  count = 2

  tags = {
    Name = "${var.project_name}-public+subnet-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  availability_zone = data.aws_availability_zones.available.names[count.index]
cidr_block = cidrsubnet(var.cidr_block, 8, count.index + 10)
  
  vpc_id = aws_vpc.this.id
  count = 2

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}



resource "aws_nat_gateway" "nat-gw" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public[0].id
    depends_on = [ aws_internet_gateway.this]

    tags = {
      Name ="${var.project_name}-nat"
    }
}

resource "aws_route_table" "route_table_public" {
    vpc_id = aws_vpc.this.id
  
  route  {
    cidr_block ="0.0.0.0/0"
    gateway_id= aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "route_assoc_public" {
    count = 2
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.route_table_public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_route_table" "route_table_private" {
    vpc_id = aws_vpc.this.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "route_assoc_private" {
    count = 2
    subnet_id = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.route_table_private.id
}
