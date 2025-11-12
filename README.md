# Transfer Image from GHCR to AWS ECR

This script transfers container images from GitHub Container Registry (ghcr.io) to AWS Elastic Container Registry (ECR).

## Prerequisites

1. **Docker** - Must be installed and running
2. **AWS CLI** - Must be installed and configured with appropriate credentials
3. **Permissions**:
   - Read access to the GitHub Container Registry image
   - Write access to AWS ECR (permissions to push images and create repositories)

## Installation

1. Download the script:
   ```bash
   chmod +x ghcr-to-ecr.sh
   ```

## Usage

### Basic Syntax

```bash
./ghcr-to-ecr.sh -s SOURCE_IMAGE -d DESTINATION_IMAGE [OPTIONS]
```

### Examples

#### Example 1: Transfer a public image
```bash
./ghcr-to-ecr.sh \
  -s ghcr.io/myorg/myapp:v1.0 \
  -d 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.0
```

#### Example 2: Transfer with specific region
```bash
./ghcr-to-ecr.sh \
  -s ghcr.io/myorg/myapp:latest \
  -d 123456789012.dkr.ecr.eu-west-1.amazonaws.com/myapp:latest \
  -r eu-west-1
```

#### Example 3: Transfer a private image (with GitHub token)
```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxx

./ghcr-to-ecr.sh \
  -s ghcr.io/myorg/private-app:v2.0 \
  -d 123456789012.dkr.ecr.us-west-2.amazonaws.com/private-app:v2.0 \
  -r us-west-2
```

#### Example 4: Using inline GitHub token
```bash
./ghcr-to-ecr.sh \
  -s ghcr.io/myorg/myapp:v1.0 \
  -d 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.0 \
  -g ghp_xxxxxxxxxxxxxxxxxxxxx
```

## Options

| Option | Description | Required |
|--------|-------------|----------|
| `-s, --source` | Source image in ghcr.io | Yes |
| `-d, --destination` | Destination image in ECR | Yes |
| `-r, --region` | AWS region (default: us-east-1) | No |
| `-g, --github-token` | GitHub personal access token | No* |
| `-h, --help` | Display help message | No |

*Required for private images

## Environment Variables

- `GITHUB_TOKEN` - GitHub personal access token for authentication
- `AWS_PROFILE` - AWS profile to use (optional)

## What the Script Does

1. **Validates inputs** - Checks that all required parameters are provided
2. **Checks prerequisites** - Verifies Docker and AWS CLI are available
3. **Authenticates to GHCR** - Logs into GitHub Container Registry (if token provided)
4. **Authenticates to ECR** - Logs into AWS ECR using AWS credentials
5. **Creates repository** - Creates the ECR repository if it doesn't exist
6. **Pulls image** - Downloads the image from ghcr.io
7. **Tags image** - Retags the image for ECR
8. **Pushes image** - Uploads the image to ECR
9. **Cleans up** - Removes local copies of the images

## Creating a GitHub Token

To access private images, you'll need a GitHub Personal Access Token with `read:packages` permission:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Select scope: `read:packages`
4. Generate token and save it securely

## AWS IAM Permissions

Your AWS credentials need the following ECR permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:CreateRepository"
      ],
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### "Failed to authenticate to AWS ECR"
Check your AWS credentials:
```bash
aws sts get-caller-identity
aws configure list
```

### "Failed to pull image from GitHub Container Registry"
- For public images: Verify the image exists and the path is correct
- For private images: Ensure your GitHub token has `read:packages` permission

### "Repository does not exist" (and creation fails)
Check your ECR permissions - you need `ecr:CreateRepository` permission.

## Advanced: Bulk Transfer

To transfer multiple images, create a list and loop:

```bash
#!/bin/bash

images=(
  "ghcr.io/myorg/app1:v1.0|app1:v1.0"
  "ghcr.io/myorg/app2:v2.0|app2:v2.0"
  "ghcr.io/myorg/app3:latest|app3:latest"
)

ECR_REGISTRY="123456789012.dkr.ecr.us-east-1.amazonaws.com"
REGION="us-east-1"

for item in "${images[@]}"; do
  SOURCE=$(echo $item | cut -d'|' -f1)
  DEST_TAG=$(echo $item | cut -d'|' -f2)
  
  ./ghcr-to-ecr.sh \
    -s "$SOURCE" \
    -d "$ECR_REGISTRY/$DEST_TAG" \
    -r "$REGION"
done
```

## Notes

- The script automatically creates the ECR repository if it doesn't exist
- Local copies of images are cleaned up after transfer
- All operations use proper error handling with colored output
