resource "aws_vpc" "app_vpc" {
    cidr_block = "10.1.0.0/16"
    tags =  {
        Name = "application_vpc"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.app_vpc.id
    tags = {
      "Name" = "app_igw"
    }
}

resource "aws_eip" "eip" {
    count = 2
    tags = {
      "Name" = "ngw_eip"
    }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnet1" {
    cidr_block = "10.1.0.0/24"
    vpc_id = aws_vpc.app_vpc.id
    availability_zone = data.aws_availability_zones.available.names[0]
    tags = {
      "Name" = "public_subnet1"
    }
}

resource "aws_subnet" "public_subnet2" {
    cidr_block = "10.1.1.0/24"
    vpc_id = aws_vpc.app_vpc.id
    availability_zone = data.aws_availability_zones.available.names[1]
    tags = {
      "Name" = "public_subnet2"
    }
}

resource "aws_subnet" "private_subnet1" {
    cidr_block = "10.1.2.0/24"
    vpc_id = aws_vpc.app_vpc.id
    availability_zone = data.aws_availability_zones.available.names[0]
    tags = {
      "Name" = "private_subnet1"
    }
}

resource "aws_subnet" "private_subnet2" {
    cidr_block = "10.1.3.0/24"
    vpc_id = aws_vpc.app_vpc.id
    availability_zone = data.aws_availability_zones.available.names[1]
    tags = {
      "Name" = "private_subnet2"
    }
}

resource "aws_nat_gateway" "ngw1" {
    allocation_id = aws_eip.eip[0].id
    connectivity_type = "public"
    subnet_id = aws_subnet.public_subnet1.id
}

resource "aws_nat_gateway" "ngw2" {
    allocation_id = aws_eip.eip[1].id
    connectivity_type = "public"
    subnet_id = aws_subnet.public_subnet2.id
}

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.app_vpc.id
    route  {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "routetableassociation1" {
    route_table_id = aws_route_table.public_route_table.id
    subnet_id = aws_subnet.public_subnet1.id
}

resource "aws_route_table_association" "routetableassociation2" {
    route_table_id = aws_route_table.public_route_table.id
    subnet_id = aws_subnet.public_subnet2.id
}

resource "aws_route_table" "private_route_table1" {
    vpc_id = aws_vpc.app_vpc.id
    route  {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.ngw1.id
    }
}

resource "aws_route_table" "private_route_table2" {
    vpc_id = aws_vpc.app_vpc.id
    route  {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.ngw2.id
    }
}

resource "aws_route_table_association" "routetableassociation3" {
    route_table_id = aws_route_table.private_route_table1.id
    subnet_id = aws_subnet.private_subnet1.id
}

resource "aws_route_table_association" "routetableassociation4" {
    route_table_id = aws_route_table.private_route_table2.id
    subnet_id = aws_subnet.private_subnet2.id
}

data "aws_ami" "ami_id" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "alb_sg" {
  name = "alb_sg"
  vpc_id = aws_vpc.app_vpc.id
  ingress  {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name = "ec2_sg"
  vpc_id = aws_vpc.app_vpc.id
  ingress  {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups =  [aws_security_group.alb_sg.id]
  }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id
  health_check {
    path = "/"
    matcher = "200"
  }
}

resource "aws_lb" "alb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_launch_template" "launchtemplate" {
    image_id = data.aws_ami.ami_id.image_id
    instance_type = "t2.micro"
    name = "app_launch_template"
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
    user_data = filebase64("./userdata.sh")
}

resource "aws_autoscaling_group" "app_asg" {
    desired_capacity = 2
    min_size = 1
    max_size = 3
    launch_template {
      id = aws_launch_template.launchtemplate.id
      version = aws_launch_template.launchtemplate.latest_version
    }
    health_check_type = "ELB"
    target_group_arns = [ aws_lb_target_group.tg.arn ]
    vpc_zone_identifier = [ aws_subnet.private_subnet1.id,aws_subnet.private_subnet2.id ]
}

