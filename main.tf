provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "hello" {
  ami           = "ami-0715c1897453cabd1"
  instance_type = "t2.micro"
  tags = {
    Name = "HelloWorld"
  }
}