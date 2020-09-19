provider "aws" {
  region  = "<region>"
  access_key = "<access_key>"
  secret_key = "<secret_key>"
}

# TERRAFORM PROJECT
# --> First we need to create a key pair from AWS>EC2 dashboard, to connect instances
# Windows users make ppk, mac/linux use ppk
# 1. Create vpc

resource "aws_vpc" "techproed-vpc-2" {
  cidr_block       = "10.0.0.0/16"
#   enable_dns_support = "true" /* We need to auto-created DNS record for auto-created public IP */
#   enable_dns_hostnames = "true" /* We need to auto-created DNS record for auto-created public IP */
  tags = {
    Name = "techproed-vpc-2"
  }
}

# 2. Create Internet Gateway --> Public IP Address

resource "aws_internet_gateway" "techproed-gw-2" {
  vpc_id = aws_vpc.techproed-vpc-2.id

  tags = {
    Name = "techproed-gw-2"
  }
}

# 3. Create Custom Route Table --> Optional but want to see

resource "aws_route_table" "techproed-route-2" {
  vpc_id = aws_vpc.techproed-vpc-2.id

  route {
    cidr_block = "0.0.0.0/0" # Default gateway
    gateway_id = aws_internet_gateway.techproed-gw-2.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.techproed-gw-2.id
  }

  tags = {
    Name = "techproed-route-2"
  }
}

# 4. Create a subnet --> submit to route table or default

resource "aws_subnet" "techproed-subnet-2" {
  vpc_id     = aws_vpc.techproed-vpc-2.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
#   map_public_ip_on_launch = "true" /* We need to "Enable auto-assign public IPv4 address" */
  tags = {
    Name = "techproed-subnet-2"
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "techproed-association-2" {
  subnet_id      = aws_subnet.techproed-subnet-2.id
  route_table_id = aws_route_table.techproed-route-2.id
}

# 6. Create Security Group to allow port 22, 80, 443

resource "aws_security_group" "techproed-securitygroup-2" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.techproed-vpc-2.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Everyone can access
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Everyone can access
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Everyone can access
  }

  egress {
    from_port   = 0 
    to_port     = 0
    protocol    = "-1" # Means any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techproed-securitygroup-2"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
# Assigning private IP addresss

resource "aws_network_interface" "techproed-interface-2" {
  subnet_id       = aws_subnet.techproed-subnet-2.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.techproed-securitygroup-2.id]
}
# 8. Assign an elastic IP to the network interface created in step 7
# One exception about order. ELASTIC IP NEEDS INTERNET GATEWAY TO BE INSTALLED FIRST

resource "aws_eip" "techproed-eip-2" {
  vpc                       = true
  network_interface         = aws_network_interface.techproed-interface-2.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.techproed-gw-2]
}

output "server_public_dns" {     # This will  print "public_dns" attribute of "techproed-eip-2" named "aws_eip" resource
    value = aws_eip.techproed-eip-2.public_dns
}

output "server_public_ip" {     # This will  print "public_ip" attribute of "techproed-eip-2" named "aws_eip" resource
    value = aws_eip.techproed-eip-2.public_ip
}

output "server_private_ip" { 
    value = aws_eip.techproed-eip-2.private_ip
}

# 9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "techproed-instance-2" {
  ami               = "ami-098f16afa9edf40be"
  instance_type     = "t2.micro" /* Free tier eligible */
  availability_zone = "us-east-1a" # The same availability zone as subnet
  key_name          = "techproed_keypair"

  network_interface {
    network_interface_id = aws_network_interface.techproed-interface-2.id
    device_index         = 0
  }
  user_data = <<-EOF
                #!/bin/bash
                sudo yum install -y httpd
                sudo bash -c 'echo "Your VERY web server" > /var/www/html/index.html'
                sudo systemctl start httpd.service
                EOF

  tags = {
    Name = "techproed-instance-2"
  }
}
