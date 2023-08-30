output "url" {
  value       = "http://${aws_lb.test_app.dns_name}/"
  description = "Access the URL and confirm that the nginx page is displayed."
}