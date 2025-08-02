provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "mykey" {
  key_name   = "web-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH"
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web_server" {
  ami                    = "ami-0c7217cdde317cfec" # Amazon Linux 2023 (us-east-1)
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.mykey.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<html><body><h1>✅ Deployed Static HTML Page via Terraform</h1></body></html>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "StaticWebServer"
  }
}

output "website_url" {
  value = "http://${aws_instance.web_server.public_ip}"
}
