variable "region" {
  default = "us-east-1"
}

variable "ami_id" {
  default = "ami-020cba7c55df1f615" # ubuntu 22.04 
}

variable "instance_type" {
    default = "t2.micro"
}