#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to display usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Transfer a container image from GitHub Container Registry (ghcr.io) to AWS ECR.

Required Options:
    -s, --source SOURCE_IMAGE       Source image in ghcr.io (e.g., ghcr.io/owner/repo:tag)
    -d, --destination DEST_IMAGE    Destination image in ECR (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/repo:tag)

Optional Options:
    -r, --region AWS_REGION         AWS region (default: us-east-1)
    -g, --github-token TOKEN        GitHub personal access token (or set GITHUB_TOKEN env var)
    -h, --help                      Display this help message

Environment Variables:
    GITHUB_TOKEN                    GitHub personal access token for authentication
    AWS_PROFILE                     AWS profile to use (optional)

Examples:
    # Basic usage
    $0 -s ghcr.io/myorg/myapp:v1.0 -d 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.0

    # With specific region
    $0 -s ghcr.io/myorg/myapp:latest -d 123456789012.dkr.ecr.eu-west-1.amazonaws.com/myapp:latest -r eu-west-1

    # Using environment variable for GitHub token
    export GITHUB_TOKEN=ghp_xxx
    $0 -s ghcr.io/myorg/myapp:v1.0 -d 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.0

Prerequisites:
    - Docker must be installed and running
    - AWS CLI must be installed and configured
    - Appropriate permissions for both registries

EOF
}

# Default values
AWS_REGION="us-east-1"
SOURCE_IMAGE=""
DEST_IMAGE=""
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s | --source)
      SOURCE_IMAGE="$2"
      shift 2
      ;;
    -d | --destination)
      DEST_IMAGE="$2"
      shift 2
      ;;
    -r | --region)
      AWS_REGION="$2"
      shift 2
      ;;
    -g | --github-token)
      GITHUB_TOKEN="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$SOURCE_IMAGE" ]]; then
  print_error "Source image is required"
  usage
  exit 1
fi

if [[ -z "$DEST_IMAGE" ]]; then
  print_error "Destination image is required"
  usage
  exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  print_error "Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &>/dev/null; then
  print_error "AWS CLI is not installed. Please install it and try again."
  exit 1
fi

print_info "Starting image transfer process..."
print_info "Source: $SOURCE_IMAGE"
print_info "Destination: $DEST_IMAGE"
print_info "AWS Region: $AWS_REGION"

# Authenticate to GitHub Container Registry if token is provided
if [[ -n "$GITHUB_TOKEN" ]]; then
  print_info "Authenticating to GitHub Container Registry..."
  echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
  if [[ $? -ne 0 ]]; then
    print_error "Failed to authenticate to GitHub Container Registry"
    exit 1
  fi
else
  print_warning "No GitHub token provided. Attempting to pull without authentication (public images only)"
fi

# Authenticate to AWS ECR
print_info "Authenticating to AWS ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$(echo "$DEST_IMAGE" | cut -d'/' -f1)"
if [[ $? -ne 0 ]]; then
  print_error "Failed to authenticate to AWS ECR"
  exit 1
fi

# Extract repository name from destination
ECR_REGISTRY=$(echo "$DEST_IMAGE" | cut -d'/' -f1)
ECR_REPO=$(echo "$DEST_IMAGE" | cut -d'/' -f2 | cut -d':' -f1)

# Check if ECR repository exists, create if it doesn't
print_info "Checking if ECR repository exists..."
if ! aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1; then
  print_warning "Repository $ECR_REPO does not exist. Creating it..."
  aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION" >/dev/null
  if [[ $? -eq 0 ]]; then
    print_info "Repository $ECR_REPO created successfully"
  else
    print_error "Failed to create repository $ECR_REPO"
    exit 1
  fi
fi

# Pull the image from GitHub Container Registry
print_info "Pulling image from GitHub Container Registry..."
docker pull "$SOURCE_IMAGE"
if [[ $? -ne 0 ]]; then
  print_error "Failed to pull image from GitHub Container Registry"
  exit 1
fi

# Tag the image for ECR
print_info "Tagging image for ECR..."
docker tag "$SOURCE_IMAGE" "$DEST_IMAGE"
if [[ $? -ne 0 ]]; then
  print_error "Failed to tag image"
  exit 1
fi

# Push the image to ECR
print_info "Pushing image to AWS ECR..."
docker push "$DEST_IMAGE"
if [[ $? -ne 0 ]]; then
  print_error "Failed to push image to AWS ECR"
  exit 1
fi

# Clean up local images (optional)
print_info "Cleaning up local images..."
docker rmi "$SOURCE_IMAGE" || print_warning "Failed to remove source image (may still be in use)"
docker rmi "$DEST_IMAGE" || print_warning "Failed to remove destination image (may still be in use)"

print_info "✓ Image transfer completed successfully!"
print_info "Image is now available at: $DEST_IMAGE"
