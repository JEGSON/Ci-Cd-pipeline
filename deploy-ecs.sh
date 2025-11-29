#!/bin/bash
set -e

# --- Configuration ---
AWS_REGION="us-east-1"
ACCOUNT_ID="318112817098"
CLUSTER_NAME="retail-store-dev-cluster"
IMAGE_TAG="e2e"

# Public subnets for FARGATE tasks (same VPC as cluster)
SUBNETS="subnet-005406d96be71c9ae,subnet-0d9cc73917b3d7e16"

# ECS tasks security group
SECURITY_GROUPS="sg-05886b71a82809363"

# ECS execution role
EXECUTION_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole"

# Services to deploy
SERVICES=("catalog" "ui" "cart" "orders" "checkout")

# --- Loop through services ---
for SERVICE in "${SERVICES[@]}"; do
  echo "🔹 Registering task definition for $SERVICE..."

  IMAGE_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/retail-store/$SERVICE:$IMAGE_TAG"

  aws ecs register-task-definition \
    --family "$SERVICE" \
    --network-mode awsvpc \
    --cpu "256" \
    --memory "512" \
    --requires-compatibilities "FARGATE" \
    --execution-role-arn "$EXECUTION_ROLE_ARN" \
    --container-definitions "[{
      \"name\": \"$SERVICE\",
      \"image\": \"$IMAGE_URI\",
      \"essential\": true,
      \"portMappings\": [{\"containerPort\": 80,\"hostPort\": 80}]
    }]" \
    --region $AWS_REGION

  echo "✅ Task definition registered for $SERVICE"

  # Check if ECS service exists
  SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE" \
    --region $AWS_REGION \
    --query "services[0].status" \
    --output text)

  if [ "$SERVICE_EXISTS" == "ACTIVE" ]; then
    echo "ℹ️ Service $SERVICE already exists. Updating service..."
    aws ecs update-service \
      --cluster "$CLUSTER_NAME" \
      --service "$SERVICE" \
      --task-definition "$SERVICE" \
      --region $AWS_REGION
    echo "✅ Service $SERVICE updated"
  else
    echo "🚀 Creating ECS service for $SERVICE..."
    aws ecs create-service \
      --cluster "$CLUSTER_NAME" \
      --service-name "$SERVICE" \
      --task-definition "$SERVICE" \
      --desired-count 1 \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=ENABLED}" \
      --region $AWS_REGION
    echo "✅ Service $SERVICE created"
  fi

done

echo "🎉 All ECS services deployed successfully!"