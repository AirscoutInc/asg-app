variable "namespace" {
  description = "Prefix for resource names"
  default = ""
}

variable "env" {
  description = "The environment for this infrastructure. E.g. dev, prod."
}

variable "task_arn" {
  description = "ARN of the SFN task this app will consume"
  default = ""
}

variable "task_name" {
  description = "AWS resource friendly name of the task (e.g. ThermalStitch)"
}

variable "app_name" {
  description = "name of the s3 folder in airscout-sw-builds"
}

variable "artifact_id" {
  description = "app artifact id if different from app_name"
  default = ""
}

variable "database" {
  description = "datasource url"
}

variable "artifact_version" {
  description = "app version from the airscout-sw-builds bucket (dev, test, etc)"
  default = "dev"
}

variable "artifact_override" {
  description = "optional full s3 path to app artifact"
  default = ""
}

variable "ami_name_prefix" {
  description = "AMI name"
  default = "*"
}

variable "ami_id" {
  description = "Specify an explicit AMI id instead of searching by name"
  default = "*"
}

//variable "aws_amis" {
//  default = {
//    "us-east-1" = "ami-5f709f34"
//    "us-west-2" = "ami-7f675e4f"
//  }
//}

variable "subnet" {
  description = "Specify either availability zones or subnets"
  default = ""
}

variable "security_groups" {
  description = "List of SGs to apply to ASG instances."
  default = ""
}

variable "key_name" {
  description = "Name of AWS key pair"
}

variable "instance_type" {
  default = "t2.small"
  description = "AWS instance type"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default = "0"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default = "1"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default = "0"
}

variable "asg_cooldown" {
  default = 600
}

variable "worker_enabled" {
  default = "true"
}

variable "stepfunctions_enabled" {
  default = "false"
}

//variable "queue_url" {
//  default = ""
//}

variable "queue_name" {
  default = ""
}

variable "fifo_queue" {
  default = "false"
}

variable "event_topic" {
  description = "ARN for the Grid Events SNS topic"
}

variable "scaling_strategy" {
  description = "Controls is ASGs are triggered via the Scalr or sqs alarms"
  default = "scalr"
}

variable "queue_name_property" {
  default = "AWS_SQS_IN_QUEUE_NAME"
}

variable "platform" {
  default = "windows"
}

variable "root_volume_type" {
  description = "Type for root volume. Make sure to match to that of the snapshot if using one."
  default = "gp2"
}

variable "root_volume_size" {
  description = "Size of root volume. Make sure to match to that of the snapshot if using one."
  default = 300
}

variable "runas" {
  default = "app"
}

variable "jvm_max" {
  default = ""
}

variable "jvm_initial" {
  default = ""
}