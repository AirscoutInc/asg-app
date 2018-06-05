output "launch_configuration" {
  value = "${aws_launch_configuration.grid-processing.id}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.grid-processing.id}"
}
