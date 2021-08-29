provider "aws" {
  region = "us-east-1"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}


resource "aws_vpc" "webapp-vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "webapp-vpc"
  }
}

resource "aws_internet_gateway" "webapp-igw" {
  vpc_id = aws_vpc.webapp-vpc.id

  tags = {
    Name = "webapp-igw"
  }
}

resource "aws_subnet" "web-1a" {
  vpc_id            = aws_vpc.webapp-vpc.id
  cidr_block        = var.web1a-cidr
  availability_zone = var.atier-az

  tags = {
    Name = "web-1a-subnet"
  }
}

resource "aws_subnet" "web-1b" {
  vpc_id            = aws_vpc.webapp-vpc.id
  cidr_block        = var.web1b-cidr
  availability_zone = var.btier-az

  tags = {
    Name = "web-1b-subnet"
  }
}

resource "aws_subnet" "app-1a" {
  vpc_id            = aws_vpc.webapp-vpc.id
  cidr_block        = var.app1a-cidr
  availability_zone = var.atier-az

  tags = {
    Name = "app-1a-subnet"
  }
}

resource "aws_subnet" "app-1b" {
  vpc_id            = aws_vpc.webapp-vpc.id
  cidr_block        = var.app1b-cidr
  availability_zone = var.btier-az

  tags = {
    Name = "app-1b-subnet"
  }
}

resource "aws_route_table" "webapp-rt" {
  vpc_id = aws_vpc.webapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webapp-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.webapp-igw.id
  }

  tags = {
    Name = "webapp-rt"
  }
}

resource "aws_route_table_association" "app-route-a" {
  subnet_id      = aws_subnet.app-1a.id
  route_table_id = aws_route_table.webapp-rt.id
}

resource "aws_route_table_association" "app-route-b" {
  subnet_id      = aws_subnet.app-1b.id
  route_table_id = aws_route_table.webapp-rt.id
}

resource "aws_route_table_association" "web-route-a" {
  subnet_id      = aws_subnet.web-1a.id
  route_table_id = aws_route_table.webapp-rt.id
}

resource "aws_route_table_association" "web-route-b" {
  subnet_id      = aws_subnet.web-1b.id
  route_table_id = aws_route_table.webapp-rt.id
}

resource "aws_security_group" "web-sg" {
  name        = "web-sg"
  description = "Web Tier Security Group"
  vpc_id      = aws_vpc.webapp-vpc.id

  ingress {
    description = "TLS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.webapp-vpc.cidr_block]
  }

  ingress {
    description = "SSH from my PC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

resource "aws_security_group" "app-sg" {
  name        = "app-sg"
  description = "Application Tier Security Group"
  vpc_id      = aws_vpc.webapp-vpc.id

  ingress {
    description = "internal from web tier http"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.web1a-cidr, var.web1b-cidr]
  }


  ingress {
    description = "internal from web tier https"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.web1a-cidr, var.web1b-cidr]
  }

  ingress {
    description = "SSH from my PC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_security_group" "db-sg" {
  name        = "db-sg"
  description = "Database Security Group"
  vpc_id      = aws_vpc.webapp-vpc.id

  ingress {
    description = "db security group for app-1a"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.app1a-cidr]
  }

  ingress {
    description = "db security group for app-1b"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.app1b-cidr]
  }

  ingress {
    description = "SSH from my PC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

resource "aws_instance" "web-ec2a" {
  ami                         = var.aws-ami
  instance_type               = "t2.micro"
  private_ip                  = lookup(var.private-ipa, "web1", "172.31.2.21")
  vpc_security_group_ids      = [aws_security_group.web-sg.id]
  subnet_id                   = aws_subnet.web-1a.id
  key_name                    = "chukky"
  associate_public_ip_address = "true"
  user_data                   = <<-EOT
    #! /bin/bash
    sudo docker run -d -p 80:80 -p 443:443 -h web1 benpiper/mtwa:web
  EOT
  tags = {
    Name = "web-1"
  }
}

resource "aws_instance" "web-ec2b" {
  count                       = 2
  ami                         = var.aws-ami
  instance_type               = "t2.micro"
  private_ip                  = lookup(var.private-ipb, "${count.index + 2}-web", "172.31.2.2${count.index + 2}")
  vpc_security_group_ids      = [aws_security_group.web-sg.id]
  subnet_id                   = aws_subnet.web-1b.id
  key_name                    = "chukky"
  associate_public_ip_address = "true"
  tags = {
    Name = "web-${count.index + 2}"
  }
}

resource "aws_instance" "app-ec2a" {
  ami                         = var.aws-ami
  instance_type               = "t2.micro"
  private_ip                  = lookup(var.private-ipa, "app1", "172.31.101.21")
  vpc_security_group_ids      = [aws_security_group.app-sg.id]
  subnet_id                   = aws_subnet.app-1a.id
  key_name                    = "chukky"
  associate_public_ip_address = "true"
  tags = {
    Name = "app-1"
  }
}

resource "aws_instance" "app-ec2b" {
  count                       = 2
  ami                         = var.aws-ami
  instance_type               = "t2.micro"
  private_ip                  = lookup(var.private-ipb, "${count.index + 2}-app", "172.31.2.2${count.index + 2}")
  vpc_security_group_ids      = [aws_security_group.app-sg.id]
  subnet_id                   = aws_subnet.app-1b.id
  key_name                    = "chukky"
  associate_public_ip_address = "true"
  tags = {
    Name = "app-${count.index + 2}"
  }
}

resource "aws_instance" "db-1" {
  ami                         = "ami-c710e7bd"
  instance_type               = "t2.micro"
  private_ip                  = lookup(var.private-ipa, "db", "172.31.101.99")
  vpc_security_group_ids      = [aws_security_group.db-sg.id]
  subnet_id                   = aws_subnet.app-1a.id
  key_name                    = "chukky"
  associate_public_ip_address = "true"
  tags = {
    Name = "dB"
  }
}

resource "aws_lb_target_group" "web-lb-tg" {
  name             = "web-servers"
  protocol         = "HTTP"
  vpc_id           = aws_vpc.webapp-vpc.id
  target_type      = "instance"
  port             = "80"
  protocol_version = "HTTP1"
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    matcher             = 200
    path                = "/"
    port                = "traffic-port"
    timeout             = 5
  }
}

resource "aws_lb_target_group_attachment" "web-tg-at-1" {
  target_group_arn = aws_lb_target_group.web-lb-tg.arn
  target_id        = aws_instance.web-ec2a.id
  port             = 80
}
