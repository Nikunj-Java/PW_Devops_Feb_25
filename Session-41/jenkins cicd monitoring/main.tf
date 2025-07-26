provider "aws" {
  region = "us-east-1"
}

# ----------- S3 Bucket for logs --------------
resource "aws_s3_bucket" "log_bucket" {
  bucket = "secure-log-bucket-jenkins-748810634002"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_enc" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ----------- IAM Role + Profile --------------
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}

# ----------- Security Group --------------
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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

# ----------- Key Pair --------------
resource "aws_key_pair" "deployer" {
  key_name   = "myjenkins-key"
  public_key = file("/mnt/c/Users/NEW/.ssh/id_rsa.pub") # update path if needed
}

# ----------- EC2 Instance with Jenkins --------------
resource "aws_instance" "jenkins_server" {
  ami                    = "ami-08a6efd148b1f7504" # Ubuntu AMI (verify region)
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y openjdk-11-jdk
              wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
              sudo sh -c 'echo deb https://pkg.jenkins.io/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
              sudo apt-get update -y
              sudo apt-get install -y jenkins awscli
              systemctl enable jenkins
              systemctl start jenkins
              EOF

  tags = {
    Name = "JenkinsServer"
  }
}

# ----------- CloudWatch Log Monitoring --------------
resource "aws_cloudwatch_log_group" "jenkins_logs" {
  name              = "/jenkins/logs"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "jenkins_stream" {
  name           = "jenkins-error-stream"
  log_group_name = aws_cloudwatch_log_group.jenkins_logs.name
}

resource "aws_cloudwatch_log_metric_filter" "error_filter" {
  name           = "jenkins-errors"
  log_group_name = aws_cloudwatch_log_group.jenkins_logs.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "JenkinsErrorCount"
    namespace = "JenkinsApp"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_alarm" {
  alarm_name          = "HighJenkinsErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "JenkinsErrorCount"
  namespace           = "JenkinsApp"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Trigger if Jenkins logs show too many errors"
  actions_enabled     = true
  alarm_actions       = [] # You can attach SNS topics here
}

# ----------- Output --------------
output "jenkins_url" {
  value = "http://${aws_instance.jenkins_server.public_ip}:8080"
}
