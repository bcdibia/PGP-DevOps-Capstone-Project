
##=================================================================================##
##Step 1 : Provider block

provider "aws" {
  region     = "us-east-1"
  access_key = "??????"
  secret_key = "??????"
}



##==================================================================================##



##Step 2 : Create a VPC
resource "aws_vpc" "k8s-vpc"{
    cidr_block = "172.16.0.0/16"
    tags = {
        Name = "My-cluster-VPC"
    }
}

output "aws_vpc_id" {
  value = aws_vpc.k8s-vpc.id
}


##=====================================================================================##


##Step 3a : Create Subnets ##
resource "aws_subnet" "cluster-public" {
  vpc_id            = aws_vpc.k8s-vpc.id
  cidr_block        = "172.16.20.0/24"

  tags = {
    Name = "k8s-subnet-pub"
  }
}

output "aws_subnet_pub_id" {
  value = aws_subnet.cluster-public.id
}

##=====================================================================================##

##Step 3b : Create Subnets ##
##resource "aws_subnet" "cluster-subnet" {
## vpc_id            = aws_vpc.k8s-vpc.id
## cidr_block        = "172.16.10.0/24"
##
##tags = {
##  Name = "k8s-subnet"
##  }
##}

##output "aws_subnet_id" {
##  value = aws_subnet.cluster-subnet.id
##}


##======================================================================================##

##Step 4a : Internet Gateway
resource "aws_internet_gateway" "myIgw" {
  vpc_id            = aws_vpc.k8s-vpc.id
}

output "aws_internet_gw" {
  value = aws_internet_gateway.myIgw.id
}

##======================================================================================##


#Step 4b : route Tables for public subnet
resource "aws_route_table" "PublicRT"{
    vpc_id = aws_vpc.k8s-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myIgw.id
    }
}

##=========================================================================================##
 
#Step 4c : route table association public subnet 
resource "aws_route_table_association" "PublicRTAssociation"{
    subnet_id = aws_subnet.cluster-public.id
    route_table_id = aws_route_table.PublicRT.id
}


##========================================================================================##


##=========================================================================================##



##==========================================================================================##



##======================================================================================##

##Step 5b : Security Group Bastian ##
resource "aws_security_group" "master_sg" {
  description = "Allow limited inbound external traffic"
  vpc_id      = aws_vpc.k8s-vpc.id
  name        = "k8s-master"

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
  }

  ingress {
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
  }

   ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 6443
    to_port     = 6443
  }

  egress {
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
  }

  tags = {
    Name = "cluster-master"
  }
}

output "aws_bastian_sg_id" {
  value = aws_security_group.master_sg.id
}

##==================================================================================##

##Step 5d : Security Group  Nodes ##
resource "aws_security_group" "k8s_nodes_sg" {
  description = "Allow limited inbound external traffic"
  vpc_id      = aws_vpc.k8s-vpc.id
  name        = "cluster_private_node_sg"
   ingress {
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
  }

  egress {
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
  }

  tags = {
    Name = "k8s_nodes_sg"
  }
}

output "aws_node_sg_id" {
  value = aws_security_group.k8s_nodes_sg.id
}

##=====================================================================================##

##Step 6 : Elastic IP for NAT Gateway

##resource "aws_eip" "nat" {
##  vpc = true
##}

##====================================================================================##

##Step 7a : Create NAT Gateway for private subnets
##resource "aws_nat_gateway" "ngw" {
##  allocation_id = aws_eip.nat.id
##  subnet_id     = aws_subnet.cluster-public.id
##  depends_on  = [aws_internet_gateway.myIgw]
##  tags = {
##    Name = "NatGateway"
##  }
##}

##output "nat_gateway_ip" {
##  value = aws_nat_gateway.ngw.id
##}

##=========================================================================================##

##Step 7b Route tables for private subnets
##resource "aws_route_table" "privatert" {
##  vpc_id = aws_vpc.k8s-vpc.id

##  route {
##    cidr_block     = "0.0.0.0/0"
##    nat_gateway_id = aws_nat_gateway.ngw.id
## }

##tags = {
##    Name = "route-table"
##  }
##}

##=========================================================================================##

##Step 7c Subents association for private subnets

##resource "aws_route_table_association" "private_subnet_association" {
##  subnet_id      = aws_subnet.cluster-subnet.id
##  route_table_id = aws_route_table.privatert.id
##}

##=======================================================================================##

##Step11 Master Instance
resource "aws_instance" "k8s_master" {
  ami             = "ami-08cc75397e83be68e"
  instance_type   = "t3.medium"
  vpc_security_group_ids      = ["${aws_security_group.master_sg.id}"]
  subnet_id                   = aws_subnet.cluster-public.id
  associate_public_ip_address = true
  key_name        = "key-2"
  tags = {
    Name = "master"
  }

}

##========================================================================================##

##Step12 Nodes Instance

resource "aws_instance" "k8s_node" {
  ami           = "ami-08cc75397e83be68e"
  instance_type = "t3.medium"
  vpc_security_group_ids      = ["${aws_security_group.k8s_nodes_sg.id}"]
  subnet_id                   = aws_subnet.cluster-public.id
  associate_public_ip_address = true
  key_name   = "node1-key"
  count      = 2
  tags = {
    Name = "worker ${count.index}"
  }

}

##=====================================================================================##

##Step13c Bastian Nodes Instance

##resource "aws_instance" "bastian_node" {
##  ami           = "ami-0557a15b87f6559cf"
##  instance_type   = "t2.micro"
##  vpc_security_group_ids      = ["${aws_security_group.sg_bastian.id}"]
##  subnet_id                   = aws_subnet.cluster-public.id
##  associate_public_ip_address = true
##  key_name        = "public-key"
##  tags = {
##    Name = "bastian_node"
##  }
##}
