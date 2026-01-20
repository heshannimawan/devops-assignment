provider "aws" {
  region = "ap-south-1" # <--- CHANGED TO MUMBAI
}

# 1. ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name = "devops-assignment-repo"
  force_delete = true
}

# 2. VPC
resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "ap-south-1a" # <--- CHANGED
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "ap-south-1b" # <--- CHANGED
}

# 3. Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-security-group"
  description = "Allow Port 8080"
  vpc_id      = aws_default_vpc.default.id

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

# 4. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "devops-assignment-cluster"
}

# 5. IAM Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_task_execution_role_assignment"

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

# 6. Task Definition
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

# 7. ECS Service
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
}