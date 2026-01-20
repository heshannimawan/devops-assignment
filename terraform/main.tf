provider "aws" {
  region = "ap-south-1" 
}

# --- 1. ECR Repository ---
resource "aws_ecr_repository" "app_repo" {
  name = "devops-assignment-repo"
  force_delete = true
}

# --- 2. Networking (VPC & Subnets) ---
resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "ap-south-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "ap-south-1b"
}

# --- 3. Security Groups ---

# Security Group for the Load Balancer (Allows Port 80 from anywhere)
resource "aws_security_group" "lb_sg" {
  name        = "alb-security-group"
  description = "Allow HTTP Port 80"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Security Group for ECS Task (Allows traffic from the Load Balancer)
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-task-sg"
  description = "Allow traffic from ALB"
  vpc_id      = aws_default_vpc.default.id

  # Allow the Load Balancer to talk to the container
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 4. Load Balancer (ALB) 
resource "aws_lb" "app_lb" {
  name               = "devops-assignment-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id]
}

# Tells the LB where to send traffic
resource "aws_lb_target_group" "app_tg" {
  name        = "devops-app-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener Listens on Port 80 (HTTP)
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --- 5. ECS Cluster & Roles ---
resource "aws_ecs_cluster" "main" {
  name = "devops-assignment-cluster"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_task_execution_role_assignment_v2" 

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- 6. Task Definition ---
resource "aws_ecs_task_definition" "app_task" {
  family                   = "node-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "node-app-container"
    image = aws_ecr_repository.app_repo.repository_url
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
  }])
}

# --- 7. ECS Service 
resource "aws_ecs_service" "app_service" {
  name            = "node-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  # CONNECTING THE LOAD BALANCER
  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "node-app-container"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.app_listener]
}

# --- Output the URL ---
output "load_balancer_url" {
  value = "http://${aws_lb.app_lb.dns_name}"
}