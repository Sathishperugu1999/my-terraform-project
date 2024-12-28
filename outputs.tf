output "loadbalancerdns" {
  value = aws_instance.aws_lb.tfalb.dns_name
  description = "The DNS name of the alb load balancer"
}