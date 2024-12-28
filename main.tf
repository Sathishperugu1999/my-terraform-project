########
#creating VPC.
########
resource "aws_vpc" "tfvpc" {
  cidr_block = "10.0.0.0/16"
}

#########
#creating public subnets.
########
resource "aws_subnet" "tfsubnet1" {
  vpc_id     = aws_vpc.tfvpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "tfsubnet2" {
  vpc_id     = aws_vpc.tfvpc.id
  cidr_block = "10.0.1.0/24"
}
############
#Creating internet gateway.
############
resource "aws_internet_gateway" "tfgateway" {
  vpc_id = aws_vpc.tfvpc.id
}
###################
#Creating route table.
##################
resource "aws_route_table" "tfroutetable" {
  vpc_id = aws_vpc.tfvpc.id

  route {
    cidr_block = "10.0.1.0/24"
    gateway_id = aws_internet_gateway.tfgateway.id
  }
}
#####################
#Creating route table association
#####################
resource "aws_route_table_association" "tfroutetableassociation1" {
  subnet_id      = aws_subnet.footfsubnet1.id
  route_table_id = aws_route_table.tfroutetable.id
}
resource "aws_route_table_association" "tfroutetableassociation2" {
  subnet_id      = aws_subnet.tfsubnet2.id
  route_table_id = aws_route_table.tfroutetable.id
}

#####################
#Creating security group
#########################
resource "aws_security_group" "tfsg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.tfvpc.id
}

resource "aws_vpc_security_group_ingress_rule" "tfsginbound1" {
  security_group_id = aws_security_group.tfsg.id
  cidr_ipv4         = aws_vpc.tfvpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "tfsginbound2" {
  security_group_id = aws_security_group.tfsg.id
  cidr_ipv4         = aws_vpc.tfvpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "tfsgoutbound" {
  security_group_id = aws_security_group.tfsg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#####################
#Creating s3 bucket.
#####################
resource "aws_s3_bucket" "tfs3" {
  bucket = var.s3bucketname
}
####################
#Create EC2 instance
####################
resource "aws_instance" "tfec21" {
  ami           = "ami-036841078a4b68e14"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.tfsg.id]
  subnet_id              = aws_subnet.tfsubnet1.id
  user_data              = base64encode(file("userdata.sh"))
}
resource "aws_instance" "tfec22" {
  ami           = "ami-036841078a4b68e14"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.tfsg.id]
  subnet_id = aws_subnet.tfsubnet1.id
  user_data = base64encode(file("userdata1.sh"))
}

############################
#Creating application load balancer
##################################
resource "aws_lb" "tfalb" {
  name               = "tfapplicationloadbalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tfsg.id]
  subnets            = [aws_subnet.tfsubnet1.id, aws_subnet.tfsubnet2.id]
}

#########################
#Creating target group for aws
##########################
resource "aws_lb_target_group" "tfalbtg" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.tfvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

#############################
#target group attachment
############################
resource "aws_lb_target_group_attachment" "tfalbtgattachment1" {
  target_group_arn = aws_lb_target_group.tfalbtg.arn
  target_id        = aws_instance.tfec21.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tfalbtgattachment2" {
  target_group_arn = aws_lb_target_group.tfalbtg.arn
  target_id        = aws_instance.tfec21.id
  port             = 80
}

######################
#Adding listener group for alb
############################
resource "aws_lb_listener" "tflistener" {
  load_balancer_arn = aws_lb.tfalb.arn
  port              = 80
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfalbtg.arn
  }
}
