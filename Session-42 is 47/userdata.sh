#!/bin/bash
yum install -y httpd
systemctl enable httpd
systemctl start httpd
echo "Hello From Terraform App - $(hostname)" > /var/www/html/index.html