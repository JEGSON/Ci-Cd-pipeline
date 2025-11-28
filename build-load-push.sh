#!/bin/bash
set -e

# Configuration
AWS_ACCOUNT_ID="318112817098"
AWS_REGION="us-east-1"
IMAGE_TAG="e2e"
SERVICES=("catalog" "ui" "cart" "orders" "checkout")
REPO_ROOT=$(pwd)

# Ensure KinD is installed
if ! command -v kind &> /dev/null; then
    echo "❌ KinD not found. Please install KinD first."
    exit 1
fi

# Ensure Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Start Docker Desktop first."
    exit 1
fi

# Build Docker images
echo "🔹 Building Docker images..."
for SERVICE in "${SERVICES[@]}"; do
    SERVICE_DIR="$REPO_ROOT/src/$SERVICE"
    IMAGE_NAME="public.ecr.aws/aws-containers/retail-store-sample-$SERVICE:$IMAGE_TAG"

    if [ ! -d "$SERVICE_DIR" ]; then
        echo "❌ Service folder missing: $SERVICE_DIR"
        exit 1
    fi

    if [ ! -f "$SERVICE_DIR/Dockerfile" ]; then
        echo "❌ Dockerfile missing in $SERVICE_DIR"
        exit 1
    fi

    echo "📦 Building $SERVICE..."
    docker build -t "$IMAGE_NAME" "$SERVICE_DIR"
done

# Load images into KinD
echo "🔹 Loading images into KinD..."
for SERVICE in "${SERVICES[@]}"; do
    IMAGE_NAME="public.ecr.aws/aws-containers/retail-store-sample-$SERVICE:$IMAGE_TAG"
    echo "🚀 Loading $IMAGE_NAME into KinD..."
    kind load docker-image "$IMAGE_NAME" --name retail-store
done

# Optional: Push to ECR
echo "🔹 Pushing images to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

for SERVICE in "${SERVICES[@]}"; do
    IMAGE_NAME="public.ecr.aws/aws-containers/retail-store-sample-$SERVICE:$IMAGE_TAG"
    ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/retail-store/$SERVICE:$IMAGE_TAG"

    docker tag "$IMAGE_NAME" "$ECR_IMAGE"
    echo "⬆ Pushing $ECR_IMAGE..."
    docker push "$ECR_IMAGE"
done

echo "✅ All images built, loaded into KinD, and pushed to ECR successfully!"