provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.2.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {

  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.prefix}-${var.env}-cicd-artifacts"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_iam_role" "codebuild_role" {
  name = "${var.prefix}-${var.env}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_inline" {
  name = "${var.prefix}-${var.env}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
        ], Resource = "*" },
      { Effect = "Allow", Action = [
          "s3:GetObject", "s3:PutObject", "s3:GetObjectVersion", "s3:ListBucket"
        ], Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"] },
      { Effect = "Allow", Action = [
          "ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload", "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"
        ], Resource = "*" }
    ]
  })
}

resource "aws_codebuild_project" "build" {
  name          = "${var.prefix}-${var.env}-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30
  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "ECR_REPO"
      value = var.ecr_repository_url
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "test/buildspec.yml"
  }
  logs_config {
    cloudwatch_logs {
      group_name = "/codebuild/${var.prefix}-${var.env}"
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.prefix}-${var.env}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_inline" {
  name = "${var.prefix}-${var.env}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = [
          "s3:GetObject", "s3:PutObject", "s3:GetObjectVersion", "s3:ListBucket"
        ], Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"] },
      { Effect = "Allow", Action = [
          "codebuild:StartBuild", "codebuild:BatchGetBuilds"
        ], Resource = [aws_codebuild_project.build.arn] },
      { Effect = "Allow", Action = [
          "codedeploy:CreateDeployment", "codedeploy:Get*", "codedeploy:RegisterApplicationRevision"
        ], Resource = "*" },
      { Effect = "Allow", Action = [
          "codestar-connections:UseConnection"
        ], Resource = var.github_connection_arn }
    ]
  })
}

resource "aws_iam_role" "codedeploy_role" {
  name = "${var.prefix}-${var.env}-codedeploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codedeploy.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_managed" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_app" "app" {
  name             = "${var.prefix}-${var.env}-codedeploy"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "dg" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${var.prefix}-${var.env}-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  autoscaling_groups    = ["ryedr-dev-asg20250908105409170700000005"]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    target_group_info { name = "${var.prefix}-${var.env}-tg" }
  }
}

resource "aws_codepipeline" "pipeline" {
  name     = "${var.prefix}-${var.env}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]
      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      version          = "1"
      configuration = { ProjectName = aws_codebuild_project.build.name }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["BuildOutput"]
      version         = "1"
      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.dg.deployment_group_name
      }
    }
  }
}

output "artifact_bucket" { value = aws_s3_bucket.artifacts.bucket }

