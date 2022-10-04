variable "instance_name" {
  description = "value of the Name Tag for EC2 instance"
  type        = string
  default     = "crdb-node"
}

variable "instance_count" {
  description = "instance count for EC2 instance"
  default     = "3"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_cidr_block" {
  default = ["172.71.0.0/26"]
}

variable "outside_ip" {
  default = ["add-local-machine-ip"]
}