resource "aws_sqs_queue" "command_queue_out" {
  count           = "${var.scaling_strategy == "scalr" && var.queue_name != "" ? 1 : 0}"
  name            = "${format("%s%s_out-%s%s", var.namespace, var.queue_name, var.env, var.fifo_queue == "true" ? ".fifo" : "")}"
  fifo_queue      = "${var.fifo_queue}"
  redrive_policy  = "${data.template_file.redrive_policy.rendered}"
  receive_wait_time_seconds = 0

  tags {
    Namespace = "${var.namespace}"
  }
}

resource "aws_sqs_queue_policy" "cross_account_access_out" {
  count = "${var.scaling_strategy == "scalr" && var.queue_grant_account_id != "" ? 1 : 0}"
  queue_url = "${aws_sqs_queue.command_queue_out.id}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.queue_grant_account_id}"
      },
      "Action": "SQS:*",
      "Resource": "${aws_sqs_queue.command_queue_out.arn}"
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "command_queue_deadletter" {
  count       = "${var.queue_name != "" ? 1 : 0}"
  name        = "${format("%s%s_deadletter-%s%s", var.namespace, var.queue_name, var.env, var.fifo_queue == "true" ? ".fifo" : "")}"
  fifo_queue  = "${var.fifo_queue}"
  
  tags {
    Namespace = "${var.namespace}"
  }
}

data "template_file" "redrive_policy" {
  count       = "${var.queue_name != "" ? 1 : 0}"
  template    = "{\"deadLetterTargetArn\":\"$${dlq}\",\"maxReceiveCount\":1}"

  vars {
    dlq = "${aws_sqs_queue.command_queue_deadletter.arn}"
  }
}

resource "aws_sqs_queue" "command_queue" {
  count           = "${var.queue_name != "" ? 1 : 0}"
  name            = "${format("%s%s-%s%s", var.namespace, var.queue_name, var.env, var.fifo_queue == "true" ? ".fifo" : "")}"
  redrive_policy  = "${var.scaling_strategy == "scalr" && var.queue_name != "" ? "" : data.template_file.redrive_policy.rendered}"
  fifo_queue      = "${var.fifo_queue}"
  receive_wait_time_seconds = 0
  content_based_deduplication = "${var.fifo_queue}"

  tags {
    Namespace = "${var.namespace}"
  }
}

resource "aws_sqs_queue_policy" "cross_account_access" {
  count = "${var.queue_grant_account_id != "" ? 1 : 0}"
  queue_url = "${aws_sqs_queue.command_queue.id}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.queue_grant_account_id}"
      },
      "Action": "SQS:*",
      "Resource": "${aws_sqs_queue.command_queue.arn}"
    }
  ]
}
POLICY
}

resource "aws_cloudwatch_metric_alarm" "add-capacity-sqs" {
  count               = "${var.scaling_strategy != "scalr" && var.queue_name != "" ? 1 : 0}"
  alarm_name          = "AddCapacityFor${var.task_name}Jobs${var.namespace}-${aws_sqs_queue.command_queue.name}-${var.env}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"

  dimensions {
    QueueName = "${aws_sqs_queue.command_queue.name}"
  }

  alarm_actions     = ["${aws_autoscaling_policy.increase-grid-processing.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "remove-capacity-sqs" {
  count               = "${var.scaling_strategy != "scalr" && var.queue_name != ""  ? 1 : 0}"
  alarm_name          = "RemoveCapacityFor${var.task_name}Jobs${var.namespace}-${aws_sqs_queue.command_queue.name}-${var.env}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "10"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"

  dimensions {
    QueueName = "${aws_sqs_queue.command_queue.name}"
  }

  alarm_actions     = ["${aws_autoscaling_policy.decrease-grid-processing.arn}"]
}

resource "aws_autoscaling_group" "grid-processing" {
  name                 = "${var.task_name}${var.namespace}-${var.env}"
  max_size             = "${var.asg_max}"
  min_size             = "${var.asg_min}"
  #desired_capacity     = "${var.asg_desired}"
  wait_for_capacity_timeout = 0
  force_delete         = true
  launch_configuration = "${aws_launch_configuration.grid-processing.name}"
  vpc_zone_identifier  = ["${split(",", var.subnet)}"]
  enabled_metrics = ["GroupInServiceInstances", "GroupDesiredCapacity", "GroupPendingInstances"]

  # so we can manually control scale-in
  protect_from_scale_in = "${var.scaling_strategy == "scalr" ? true : false}"

  tag {
    key                 = "environment"
    value               = "${var.env}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "Name"
    value               = "${var.task_name}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "APP_NAME"
    value               = "${var.app_name}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "ARTIFACT_ID"
    value               = "${var.artifact_id == "" ? var.app_name : var.artifact_id}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "VERSION"
    value               = "${var.artifact_version}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "ARTIFACT_OVERRIDE"
    value               = "${var.artifact_override}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "TASK_ARN"
    value               = "${var.task_arn}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "AIRSCOUT_STEPFUNCTIONS_ENABLED"
    value               = "${var.stepfunctions_enabled}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "AIRSCOUT_WORKER_ENABLED"
    value               = "${var.worker_enabled}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "SQS_CONTROLLER_ENABLED"
    value               = "${var.stepfunctions_enabled == "true" ? "false" : "true"}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "SPRING_DATASOURCE_URL"
    value               = "jdbc:mysql://${var.database}"
    propagate_at_launch = "true"
  }

  #https://github.com/hashicorp/terraform/issues/11566#issuecomment-289417805
  tag {
    key                 = "${var.queue_name_property}"
    value               = "${var.scaling_strategy != "scalr" ? join(" ", aws_sqs_queue.command_queue.*.id) : join(" ", aws_sqs_queue.command_queue_out.*.id)}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "AIRSCOUT_MONITORING_GRID_EVENT_SNS_TOPIC"
    value               = "${var.event_topic}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "RUNAS"
    value               = "${var.runas}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "JVM_MAX"
    value               = "${var.jvm_max}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "JVM_INITIAL"
    value               = "${var.jvm_initial}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "Namespace"
    value               = "${var.namespace}"
    propagate_at_launch = "true"
  }
}

resource "aws_autoscaling_policy" "increase-grid-processing" {
  name                   = "ScaleOut"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.asg_cooldown}"
  autoscaling_group_name = "${aws_autoscaling_group.grid-processing.name}"
}

resource "aws_autoscaling_policy" "decrease-grid-processing" {
  name                   = "ScaleIn"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.asg_cooldown / 2}"
  autoscaling_group_name = "${aws_autoscaling_group.grid-processing.name}"
}

data "aws_ami" "app_ami" {
  most_recent      = true
  //executable_users = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_name_prefix}*"]
  }

  filter {
    name = "image-id"
    values = ["${var.ami_id}"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

// Assume this role exists for now. If we need more flexibility in the future this should be passed in as a variable.
data "aws_iam_instance_profile" "grid_processor" {
  name = "GridProcessor"
}

resource "aws_launch_configuration" "grid-processing" {
  # Don't specify a name here so terraform can safely update the launch config
  image_id             = "${data.aws_ami.app_ami.id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${data.aws_iam_instance_profile.grid_processor.role_name}"
  enable_monitoring    = false

  # Security group
  security_groups = ["${split(",",var.security_groups)}"]
  key_name        = "${var.key_name}"

  //user_data = "${file(format("%s/%s", path.module, data.aws_ami.app_ami.platform == "windows" ? "windows-bootstrap.txt" : "linux-bootstrap.sh"))}"
  user_data = "${file(format("%s/%s", path.module, var.platform == "windows" ? "windows-bootstrap.txt" : var.platform == "linux_test" ? "linux-bootstrap-test.sh" : "linux-bootstrap.sh"))}"

  root_block_device {
    delete_on_termination = true
    volume_size = "${var.root_volume_size}"
    volume_type = "${var.root_volume_type}"
  }

  lifecycle {
    create_before_destroy = true
  }
}
