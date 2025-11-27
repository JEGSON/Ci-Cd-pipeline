#!/bin/bash

set -e

echo "🚀 Starting ECS Deployment Script..."
echo ""

# Check if DB password is set
if [ -z "$TF_VAR_db_password" ]; then
    echo "❌ Error: TF_VAR_db_password not set"
    echo "Please run: export TF_VAR_db_password='YourPassword'"
    exit 1
fi

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="us-east-1"

echo "📋 AWS Account ID: $AWS_ACCOUNT_ID"
echo "🌍 Region: $AWS_REGION"
echo ""

# Get Terraform outputs
echo "📊 Fetching infrastructure details from Terraform..."
cd ../terraform

export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
export ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
export TARGET_GROUP=$(terraform output -raw ui_target_group_arn)
export SUBNET1=$(terraform output -json private_subnet_ids | jq -r '.[0]')
export SUBNET2=$(terraform output -json private_subnet_ids | jq -r '.[1]')
export ECS_SG=$(terraform output -raw ecs_security_group_id)

echo "✅ RDS Endpoint: $RDS_ENDPOINT"
echo "✅ ECS Cluster: $ECS_CLUSTER"
echo "✅ Subnets: $SUBNET1, $SUBNET2"
echo "✅ Security Group: $ECS_SG"
echo ""

cd ../ecs-tasks

# Create UI Task Definition
echo "📝 Creating UI task definition..."
cat > ui-task-definition.json <<TASKDEF
{
  "family": "retail-store-dev-ui",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-dev-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-dev-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "ui",
      "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/retail-store/ui:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "prod"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/retail-store-dev/ui",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
TASKDEF

echo "✅ UI task definition file created"

# Create Catalog Task Definition
echo "�� Creating Catalog task definition..."
cat > catalog-task-definition.json <<TASKDEF
{
  "family": "retail-store-dev-catalog",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-dev-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-dev-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "catalog",
      "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/retail-store/catalog:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "DB_ENDPOINT",
          "value": "${RDS_ENDPOINT}"
        },
        {
          "name": "DB_NAME",
          "value": "catalog"
        },
        {
          "name": "DB_USER",
          "value": "admin"
        },
        {
          "name": "DB_PASSWORD",
          "value": "${TF_VAR_db_password}"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/retail-store-dev/catalog",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
TASKDEF

echo "✅ Catalog task definition file created"
echo ""

# Register Task Definitions
echo "📤 Registering task definitions with ECS..."
aws ecs register-task-definition --cli-input-json file://ui-task-definition.json --region $AWS_REGION > /dev/null
echo "✅ UI task definition registered"

aws ecs register-task-definition --cli-input-json file://catalog-task-definition.json --region $AWS_REGION > /dev/null
echo "✅ Catalog task definition registered"
echo ""

# Create ECS Services
echo "🚀 Creating ECS services..."

# Create UI Service (with Load Balancer)
echo "Creating UI service..."
aws ecs create-service \
  --cluster $ECS_CLUSTER \
  --service-name ui \
  --task-definition retail-store-dev-ui \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET1,$SUBNET2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$TARGET_GROUP,containerName=ui,containerPort=8080" \
  --health-check-grace-period-seconds 60 \
  --region $AWS_REGION > /dev/null

echo "✅ UI service created"

# Create Catalog Service
echo "Creating Catalog service..."
aws ecs create-service \
  --cluster $ECS_CLUSTER \
  --service-name catalog \
  --task-definition retail-store-dev-catalog \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET1,$SUBNET2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --region $AWS_REGION > /dev/null

echo "✅ Catalog service created"
echo ""

echo "✨ Deployment complete!"
echo ""
echo "🔍 Checking service status..."
aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services ui catalog \
  --region $AWS_REGION \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table

echo ""
echo "🌐 Your application will be available at:"
cd ../terraform
ALB_URL=$(terraform output -raw alb_url)
echo "   $ALB_URL"
cd ../ecs-tasks

echo ""
echo "⏰ Wait 2-3 minutes for services to start and health checks to pass"
echo ""
echo "📊 Monitor deployment with:"
echo "   aws ecs describe-services --cluster $ECS_CLUSTER --services ui --region $AWS_REGION"
echo ""
echo "📝 View logs with:"
echo "   aws logs tail /ecs/retail-store-dev/ui --follow --region $AWS_REGION"
echo ""
echo "🔄 Check task status:"
echo "   aws ecs list-tasks --cluster $ECS_CLUSTER --service ui --region $AWS_REGION"
