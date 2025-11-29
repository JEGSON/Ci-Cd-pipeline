#!/bin/bash
set -e

AWS_REGION="us-east-1"
ACCOUNT_ID="318112817098"
EXECUTION_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole"
IMAGE_TAG="e2e"

SERVICES=("ui" "cart" "orders" "checkout")

for SERVICE in "${SERVICES[@]}"; do
  echo "Registering task definition for $SERVICE..."
  aws ecs register-task-definition \
    --family "$SERVICE" \
    --network-mode awsvpc \
    --cpu "256" \
    --memory "512" \
    --requires-compatibilities "FARGATE" \
    --execution-role-arn "$EXECUTION_ROLE_ARN" \
    --container-definitions "[{
      \"name\": \"$SERVICE\",
      \"image\": \"$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/retail-store/$SERVICE:$IMAGE_TAG\",
      \"essential\": true,
      \"portMappings\": [{\"containerPort\": 80,\"hostPort\": 80}]
    }]" \
    --region $AWS_REGION
done
