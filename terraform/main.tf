###############################################
###                 Provider                ###
###############################################

provider "aws" {
  region                  = "${var.aws_region}"
  shared_credentials_file = "${var.aws_credentials}"
  profile                 = "${var.aws_profile}"
}

###############################################
###                 Network                 ###
###############################################

# Declare the data source
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create private subnets
resource "aws_subnet" "private" {
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  count             = "${var.az_number}"
  vpc_id            = "${aws_vpc.main.id}"
}

# Create public subnets
resource "aws_subnet" "public" {
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 8, var.az_number + count.index)}"
  count                   = "${var.az_number}"
  map_public_ip_on_launch = true
  vpc_id                  = "${aws_vpc.main.id}"
}

# Public subnet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

# Route public traffic
resource "aws_route" "internet_access" {
  destination_cidr_block = "${var.cidr_block}"
  gateway_id             = "${aws_internet_gateway.gw.id}"
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
}

# Create NAT gateway and EIP
resource "aws_eip" "gw" {
  count      = "${var.az_number}"
  depends_on = ["aws_internet_gateway.gw"]
  vpc        = true
}

resource "aws_nat_gateway" "gw" {
  count         = "${var.az_number}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
}

# Create and attach route table for private subnets
resource "aws_route_table" "private" {
  count  = "${var.az_number}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block     = "${var.cidr_block}"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }
}

resource "aws_route_table_association" "private" {
  count          = "${var.az_number}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
}

###############################################
###                 Security                ###
###############################################

# ALB Security Group: Edit this to restrict access to the application
resource "aws_security_group" "lb" {
  name        = "rescale-load-balancer-security-group"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 5000
    to_port     = 5000
    cidr_blocks = ["${var.cidr_block}"]
}

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.cidr_block}"]
  }
}

# Traffic to the ECS cluster via load balancer
resource "aws_security_group" "ecs_tasks" {
  name        = "rescale-ecs-tasks-security-group"
  description = "allow inbound access from the load balancer"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.app_port}"
    to_port         = "${var.app_port}"
    security_groups = ["${aws_security_group.lb.id}"]
}

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.cidr_block}"]
  }
}

###############################################
###               Load balancer             ###
###############################################

resource "aws_alb" "main" {
  name               = "rescale-load-balancer"
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb.id}"]
  subnets            = ["${aws_subnet.public.*.id}"]
}

resource "aws_alb_target_group" "app" {
  name        = "rescale-target-group"
  port        = "${var.app_port}"
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "${var.lb_port}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.app.id}"
    type             = "forward"
  }
}

###############################################
###                ECS cluster              ###
###############################################


resource "aws_ecs_cluster" "rescale" {
  name = "rescale-cluster"
}

# Define the task definition
resource "aws_ecs_task_definition" "app" {
  cpu                      = 1024
  memory                   = 2048
  family                   = "app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = "${var.ecs_task_execution_role}"

  container_definitions = <<DEFINITION
[
  {
    "name": "portal",
    "image": "415868856706.dkr.ecr.us-east-1.amazonaws.com/portal:latest",
    "essential": true,
    "memory": ${var.fargate_memory},
    "cpu": ${var.fargate_cpu},
    "portMappings": [
      {
        "containerPort": ${var.app_port}
      }
    ]
  },
  {
    "name": "hardware",
    "image": "415868856706.dkr.ecr.us-east-1.amazonaws.com/hardware:latest",
    "essential": true,
    "memory": ${var.fargate_memory},
    "cpu": ${var.fargate_cpu},
    "portMappings": [
      {
        "containerPort": 5001
      }
    ]
  },
  {
    "name": "mysql",
    "image": "415868856706.dkr.ecr.us-east-1.amazonaws.com/mysql:latest",
    "memory": ${var.fargate_memory},
    "cpu": ${var.fargate_cpu},
    "essential": true
  }
]
DEFINITION
}

resource "aws_ecs_service" "app" {
  cluster         = "${aws_ecs_cluster.rescale.id}"
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"
  name            = "app-service"
  task_definition = "${aws_ecs_task_definition.app.arn}"

  network_configuration {
    assign_public_ip = true
    security_groups  = ["${aws_security_group.ecs_tasks.id}"]
    subnets          = ["${aws_subnet.private.*.id}"]
  }

  load_balancer {
    container_name   = "portal"
    container_port   = "${var.app_port}"
    target_group_arn = "${aws_alb_target_group.app.id}"
  }

  depends_on = [
    "aws_alb_listener.front_end",
  ]
}

