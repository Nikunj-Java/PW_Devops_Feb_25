output "bucket_name" {
  value = aws_s3_bucket.my_bucket.bucket
}

output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.s3_4xx_alarm.alarm_name
}
