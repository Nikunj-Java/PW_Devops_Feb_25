provider "aws" {
    alias = "us_east"
    region = "us-east-1"
}
provider "aws" {
    alias = "eu_west"
    region = "eu-west-1"
}
#---------Networking (VPC+ Subnet)------------
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    provider = aws.us_east
}

resource "aws_subnet" "subnet1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    provider = aws.us_east
}

resource "aws_subnet" "subnet2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    provider = aws.us_east
}

#-------------Security Group--------------
resource "aws_security_group" "web_sg" {
    name = "web-sg"
    description = "Allow HTTP"
    vpc_id = aws_vpc.main.id
    provider=aws.us_east
    ingress{
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }   
}

#--------------EC2 Instance-------------
# 3. EC2 Key Pair
resource "aws_key_pair" "my_key" {
  key_name   = "imported-key"
  public_key = file("/mnt/c/Users/NEW/.ssh/id_rsa.pub")
}

resource "aws_instance" "web" {
    ami = "ami-08a6efd148b1f7504"
    instance_type = "t3.micro"
    subnet_id = aws_subnet.subnet1.id
    vpc_security_group_ids = [aws_security_group.web_sg.id]
    key_name = aws_key_pair.my_key.key_name
    provider = aws.us_east
    tags = {
        Name="WebServer"
    }
    user_data = <<-EOF
                #!/bin/bash
                yum install -y httpd
                systemctl enable httpd
                systemctl start httpd
                echo "<h1> Deployed in US EAST-1a</h1>" > /var/www/html/index.html
                EOF
}

#--Auto Scaling
resource "aws_launch_template" "web_lt" {
    name_prefix = "web-lt"
    image_id = "ami-08a6efd148b1f7504"
    instance_type = "t3.micro"
    provider = aws.us_east

    user_data = base64encode("#/bin/bash\nyum install -y httpd\nsystemctl start httpd")
}

resource "aws_autoscaling_group" "web_asg" {
    desired_capacity = 1
    max_size = 2
    min_size = 1
    vpc_zone_identifier = [aws_subnet.subnet1.id,aws_subnet.subnet2.id]
    health_check_type = "EC2"
    launch_template {
      id = aws_launch_template.web_lt.id 
      version ="$Latest"
    }
    provider = aws.us_east 
}

# ----------- CloudWatch Log Monitoring --------------
resource "aws_cloudwatch_log_group" "webs_logs" {
  name              = "/web/app/logs"
  retention_in_days = 7
  provider = aws.us_east
}
#-------------Cloud Watch Logs and Metrics
resource "aws_cloudwatch_metric_alarm" "jenkins_alarm" {
  alarm_name          = "High-CPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "JenkinsApp"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Trigger if CPU >70% for 2 minutes"
  dimensions = {
    InstanceId=aws_instance.web.id
  }
  provider = aws.us_east
}

# ----------- S3 Bucket for Static Website(Multi Region) --------------
resource "aws_s3_bucket" "east_bucket" {
  bucket = "web-static-us"
  provider = aws.us_east
}
resource "aws_s3_bucket" "west_bucket" {
  bucket = "web-static-eu"
  provider = aws.eu_west
}

#------------ outputs-------------------
output "instance_public_ip"{
    value = aws_instance.web.public_ip
}

output "web_log_group" {
    value = aws_cloudwatch_log_group.webs_logs.name
}

output "east_bucket" {
    value = aws_s3_bucket.east_bucket.bucket
}

output "west_bucket" {
  value = aws_s3_bucket.west_bucket.bucket
}
