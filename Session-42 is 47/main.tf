provider "aws" {
    region = var.region
  
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
    filter {
      name="vpc-id"
      values=[data.aws_vpc.default.id]
    }
}

resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Allow SSH and Jenkins"

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_launch_template" "app_template" {
    name_prefix = "app-template-"
    image_id = "" # amazon linux ami id
    instance_type = var.instance_type
    key_name = var.key_name
    user_data = filebase64(("userdata.sh"))
  
}

resource "aws_lb_target_group" "app_tg" {
    name = "app-tg"
    port = 80
    protocol = "HTTP"
    vpc_id= data.aws_vpc.default.id
    health_check {
      path = "/"
      port = 80
    }
}

resource "aws_lb" "app_alb" {
    name = "app-lb"
    internal = false
    load_balancer_type = "application"
    subnets=data.aws_subnets.default.ids
    security_groups = [aws_security_group.lb_sg.id]
  
}
resource "aws_lb_listener" "app_listner" {
    load_balancer_arn = aws_lb.app_alb.arn
    port = 80
    protocol = "HTTP"
    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.app_tg.arn
    }
  
}

resource "aws_autoscaling_group" "asg" {
    desired_capacity = 1
    max_size = 3
    min_size = 1
    vpc_zone_identifier = data.aws_subnets.default.ids

    launch_template {
      id = aws_launch_template.app_template.id
      version = "$Latest"
    }
    target_group_arns = [aws_lb_target_group.app_tg.arn]
    health_check_type = "EC2"
}

#SNS Topic & Alarms
# give Amazon SNS Full Access to user
resource "aws_sns_topic" "alerts" {
    name="alerts-topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
    topic_arn = aws_sns_topic.alerts.arn
    protocol = "email"
    endpoint = "youremailid@gmail.com"
}
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Monitors High CPU"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn] # You can attach SNS topics here
}


resource "aws_autoscaling_policy" "scale_up" {
  name = "scale-up-policy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}