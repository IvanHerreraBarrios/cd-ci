resource "aws_ecs_cluster" "main" {
  name = "ecs-controller-cluster"

  tags = {
    Name = "ecs-controller-cluster"
  }
}

resource "aws_cloudwatch_log_group" "ecs_controller" {
  name              = "/ecs/ecs-controller"
  retention_in_days = 7

  tags = {
    Name = "ecs-controller-logs"
  }
}

resource "aws_ecs_task_definition" "ecs_controller" {
  family                   = "ecs-controller"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = var.ecs_cpu
  memory = var.ecs_memory

  execution_role_arn = "arn:aws:iam::127621463335:role/studentEcsTaskExecutionRole"

  container_definitions = jsonencode([
    {
      name      = "ecs-controller"
      image     = "${aws_ecr_repository.ecs_controller.repository_url}:${var.docker_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_controller.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "ecs-controller-task"
  }
}

resource "aws_ecs_service" "ecs_controller" {
  name            = "ecs-controller-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ecs_controller.arn

  desired_count = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_controller.arn
    container_name   = "ecs-controller"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  depends_on = [
    aws_lb_listener.http
  ]

  tags = {
    Name = "ecs-controller-service"
  }
}
