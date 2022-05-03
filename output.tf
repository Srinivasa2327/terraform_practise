output "vpc_id" {
  value = aws_vpc.app_vpc.id
}

output "ami_id" {
  value = data.aws_ami.ami_id
}