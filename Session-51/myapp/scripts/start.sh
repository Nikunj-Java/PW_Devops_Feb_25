#!/bin/bash
set -e
sudo dnf install -y httpd
sudo systemctl enable httpd
sudo systemctl restart httpd