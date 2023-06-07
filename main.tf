terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.44.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Create SSH 

# resource "tls_private_key" "key" {
#   algorithm = "RSA"
# }

# resource "aws_key_pair" "key_pair" {
#   key_name   = "key_pair"
#   public_key = tls_private_key.key.public_key_openssh
# }

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    "Name" = "VPC-Terraform"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    "Name" = "IG-Terraform"
  }
}

# Create route to go internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    "Name" = "Public-Rb-Terraform"
  }
}

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    "Name" = "Public-Subnet-Terraform"
  }
  # map_public_ip_on_launch = true
}

# Association 
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "allow_ssh" {
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All traffic
  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG_Terraform"
  }
}

# resource "aws_security_group" "allow_all" {
# vpc_id      = aws_vpc.vpc.id
# name        = "allow_all"
# description = "Allow all inbound traffic"

# # All TCP Port
# ingress {
#   from_port   = 0
#   to_port     = 65535
#   protocol    = "tcp"
#   cidr_blocks = ["0.0.0.0/0"]
# }

# # All traffic
# ingress {
#   protocol  = -1
#   self      = true
#   from_port = 0
#   to_port   = 0
# }

#   ingress {
#   from_port   = 80
#   to_port     = 80
#   protocol    = "tcp"
#   cidr_blocks = ["0.0.0.0/0"]
# }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "allow_all"
#   }
# }

# Create EC2 Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical Ubuntu AWS account id
}

resource "aws_instance" "EC2-Terraform-01" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  # key_name               = aws_key_pair.key_pair.key_name
  key_name = "key_pair"
  tags = {
    Name = "EC2-Terraform-01"
  }
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
}

# resource "aws_instance" "EC2-Terraform-02" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.allow_ssh.id]
#   # key_name               = aws_key_pair.key_pair.key_name
#   key_name               = "key_pair"
#   tags = {
#     Name = "EC2-Terraform-02"
#   }
#   subnet_id                   = aws_subnet.public_subnet.id
#   associate_public_ip_address = true
# }


resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"

  tags = {
    "Name" = "Private-Subnet-Terraform"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "public" {
  depends_on = [aws_internet_gateway.ig]

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "Public NAT in Public Subnet"
  }
}

# Create Route Table assign to NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.public.id
  }

  tags = {
    "Name" = "Private_Rb_Terraform"
  }
}

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.vpc.id

#   # route {
#   #   cidr_block = "0.0.0.0/0"
#   #   gateway_id = aws_nat_gateway.public.id
#   # }

#   tags = {
#     "Name" = "Private_Rb_Terraform"
#   }
# }

resource "aws_route_table_association" "private-association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id

  # for_each = toset([aws_subnet.public_subnet.id, aws_subnet.private_subnet.id])
  # subnet_id      = each.value
  # route_table_id = aws_route_table.private.id

}


resource "aws_security_group" "allow_all_traffic" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG_Terraform_All_Traffic"
  }
}

resource "aws_instance" "EC2-Terraform-03" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  # vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  vpc_security_group_ids = [aws_security_group.allow_all_traffic.id]
  # key_name               = aws_key_pair.key_pair.key_name
  key_name = "key_pair"
  tags = {
    Name = "EC2-Terraform-03"
  }
  subnet_id = aws_subnet.private_subnet.id
  # associate_public_ip_address = true
}

#create a security group for RDS Database Instance
resource "aws_security_group" "rds_sg" {
  name   = "rds_sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "SG_RDS_Terraform"
  }
}

#make rds subnet group
resource "aws_db_subnet_group" "rdssubnet" {
  name = "database subnet"
  #subnet_ids  = [aws_subnet.rds_subnet_[0].id, aws_subnet.rds_subnet_[1].id, aws_subnet.rds_subnet_[2].id]
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.public_subnet.id]
}

# #create a RDS Database Instance
resource "aws_db_instance" "database" {
  engine               = "mysql"
  identifier           = "database"
  allocated_storage    = 20
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  username             = "sangnd"
  password             = "12345678"
  parameter_group_name = "default.mysql5.7"
  # vpc_security_group_ids = ["${aws_security_group.rds_sg.id}"]
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true
  db_subnet_group_name   = aws_db_subnet_group.rdssubnet.name
}

# sudo apt install mysql-server
# SELECT table_name FROM information_schema.tables;
# mysql -u sangnd -h database.cdotunbathmn.us-west-2.rds.amazonaws.com  -p
