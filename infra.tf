provider "aws" {
  region     = "us-east-1"
  access_key = "***************
  "
  secret_key = "***************"
}

variable "myip" {
}

variable "vpc_prefix" {
}
variable "subnet_prefix" {
}

resource "aws_vpc" "dev_vpc" {
    cidr_block = var.vpc_prefix[0].cidr_block

    tags = {
        "name" = var.vpc_prefix[0].name
    }
}
resource "aws_subnet" "PB1" {
    vpc_id = aws_vpc.dev_vpc.id
    cidr_block = var.subnet_prefix[0].cidr_block
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
      "name" = var.subnet_prefix[0].name
    }
}
resource "aws_subnet" "PR1" {
    vpc_id = aws_vpc.dev_vpc.id
    cidr_block = var.subnet_prefix[1].cidr_block
    availability_zone = "us-east-1b"
    tags = {
      "name" = var.subnet_prefix[1].name
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.dev_vpc.id

    tags = {
        "name" = "igw1"
    }
}

resource "aws_route_table" "RT" {
    vpc_id = aws_vpc.dev_vpc.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id 
    }

    tags = {
        "name" = "PBRT"
    }
}

resource "aws_route_table" "RT2" {
    vpc_id = aws_vpc.dev_vpc.id

    tags = {
        "name" = "PRRT"
    }
}

resource "aws_route_table_association" "RTA" {
    subnet_id = aws_subnet.PB1.id 
    route_table_id = aws_route_table.RT.id
}
resource "aws_route_table_association" "RTA1" {
    subnet_id = aws_subnet.PR1.id 
    route_table_id = aws_route_table.RT2.id
}



resource "aws_security_group" "PBSG" {
    vpc_id = aws_vpc.dev_vpc.id

    ingress {
    description      = "Port to allow traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    }
    ingress {
    description      = "Port to allow traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.myip
    }
  
}
resource "aws_security_group" "PRSG" {
    vpc_id = aws_vpc.dev_vpc.id

    ingress {
    description      = "Port to allow traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.myip
    }
  
}
resource "aws_network_interface" "ani" {
  subnet_id   = aws_subnet.PB1.id
  private_ips = ["10.0.1.10"]

  tags = {
    Name = "primary_eni"
  }
}

resource "aws_network_interface" "pni" {
  subnet_id   = aws_subnet.PR1.id
  private_ips = ["10.0.2.10"]

  tags = {
    Name = "primary_eni_pr"
  }
}
resource "aws_instance" "server" {
  ami           = "ami-0ed9277fb7eb570c9"
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.iam_profile.name

  network_interface {
    network_interface_id = aws_network_interface.ani.id
    device_index         = 0
  }
  tags = {
    "Name" = "Web-server"
  }
}

resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.PBSG.id
  network_interface_id = aws_instance.server.primary_network_interface_id
}

resource "aws_instance" "dev" {
  ami           = "ami-0ed9277fb7eb570c9"
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.pni.id
    device_index         = 0
  }
  tags = {
    "Name" = "dev-server"
  }
}

resource "aws_network_interface_sg_attachment" "sg_attachment1" {
  security_group_id    = aws_security_group.PRSG.id
  network_interface_id = aws_instance.dev.primary_network_interface_id
}

resource "aws_iam_role" "role" {
  name = "s3-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "s3-policy"
  description = "A s3 access policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "role-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam_profile"
  role = aws_iam_role.role.name
}

resource "aws_s3_bucket" "bucket" {
  acl    = "public-read"
}
