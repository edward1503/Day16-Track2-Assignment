output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ml_alb_dns_name" {
  value = aws_lb.ml_alb.dns_name
  description = "The DNS name of the ALB"
}

output "ui_url" {
  value = "http://${aws_lb.ml_alb.dns_name}"
  description = "URL for the Streamlit UI"
}

output "api_url" {
  value = "http://${aws_lb.ml_alb.dns_name}:8000"
  description = "URL for the FastAPI API"
}

output "ml_node_private_ip" {
  value = aws_instance.ml_node.private_ip
}