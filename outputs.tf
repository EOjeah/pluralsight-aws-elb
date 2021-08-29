output "web-1-public-ip" {
  value = "http://${aws_instance.web-ec2a.public_ip}"
}

output "web-2-public-ip" {
  value = "http://${aws_instance.web-ec2b[0].public_ip}"
}

output "web-3-public-ip" {
  value = "http://${aws_instance.web-ec2b[1].public_ip}"
}

output "web-1-public-dns" {
  value = "http://${aws_instance.web-ec2a.public_dns}"
}

output "web-2-public-dns" {
  value = "http://${aws_instance.web-ec2b[0].public_dns}"
}

output "web-3-public-dns" {
  value = "http://${aws_instance.web-ec2b[1].public_dns}"
}

