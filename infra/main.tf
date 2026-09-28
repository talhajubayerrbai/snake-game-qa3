terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # bucket, key, region passed via -backend-config at init time
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Variables ──────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ssh_public_key" {
  description = "Public key material for the EC2 key pair"
  type        = string
}

variable "project_name" {
  description = "Project name used for tagging and naming"
  type        = string
  default     = "snake-game-qa3"
}

# ── Data ───────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ── S3 Artifact Bucket ─────────────────────────────────────────────────────────

resource "aws_s3_bucket" "artifacts" {
  bucket        = "snake-game-qa3-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-artifacts"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── SSH Key Pair ───────────────────────────────────────────────────────────────

resource "aws_key_pair" "snake_game" {
  key_name   = "snake-game-qa3-key"
  public_key = var.ssh_public_key

  tags = {
    Name    = "snake-game-qa3-key"
    Project = var.project_name
  }
}

# ── IAM Instance Profile ───────────────────────────────────────────────────────

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "snake_game" {
  name               = "${var.project_name}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name    = "${var.project_name}-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.snake_game.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow EC2 to read from the artifact bucket
resource "aws_iam_role_policy" "s3_artifact_read" {
  name = "${var.project_name}-s3-artifact-read"
  role = aws_iam_role.snake_game.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::snake-game-qa3-artifacts-${data.aws_caller_identity.current.account_id}",
        "arn:aws:s3:::snake-game-qa3-artifacts-${data.aws_caller_identity.current.account_id}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "snake_game" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.snake_game.name

  tags = {
    Name    = "${var.project_name}-profile"
    Project = var.project_name
  }
}

# ── Security Group ─────────────────────────────────────────────────────────────

resource "aws_security_group" "snake_game" {
  name        = "${var.project_name}-sg"
  description = "Security group for snake-game-qa3"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# ── EC2 Instance ───────────────────────────────────────────────────────────────

resource "aws_instance" "snake_game" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.snake_game.key_name
  vpc_security_group_ids = [aws_security_group.snake_game.id]
  iam_instance_profile   = aws_iam_instance_profile.snake_game.name

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.snake_game.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.snake_game.id
}

output "artifact_bucket_name" {
  description = "Name of the S3 artifact bucket"
  value       = aws_s3_bucket.artifacts.bucket
}
