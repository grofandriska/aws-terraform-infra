data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "instance_sg" {
  name_prefix = "${var.project_name}-instance-sg-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP csak a load balancertol"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lb_security_group_id]
  }

  egress {
    description = "Kimeno forgalom (SSM, csomagfrissitesek)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance_sg.id]
  }

  # IMDSv2 kötelező
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(file("${path.module}/user_data.sh"))
}

resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.project_name}-asg-"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns

  # Ha a webszerver nem válaszol, az ASG lecseréli a gépet
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # Launch template változáskor fokozatosan lecseréli a gépeket
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web"
    propagate_at_launch = true
  }

  # A darabszámot a skálázási szabály állítja, a Terraform ne írja vissza
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}