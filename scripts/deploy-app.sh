#!/bin/bash
set -euo pipefail

ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# GitHub Actions から渡された TAG を使う
IMAGE_TAG="${1:-latest}"  # 例: v1.2.3（引数がなければ latest にフォールバック）

TASK_NAME="${ENV}-${PROJECT}-task"
CONTAINER_NAME="${ENV}-${PROJECT}-app"
LOG_GROUP="/ecs/${ENV}-${PROJECT}"
S3_BUCKET="codeploy-bundles"
S3_KEY="${ENV}-${PROJECT}/${IMAGE_TAG}/bundle.zip"

echo "🔍 CloudFormation Output から値を取得中..."

# === CloudFormationから各種値を取得 ===
ECR_REPO=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-ecr \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" \
  --output text --region $REGION)

TASK_EXEC_ROLE=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECSTaskExecutionRoleArn'].OutputValue" \
  --output text --region $REGION)

SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-secrets \
  --query "Stacks[0].Outputs[?OutputKey=='SecretArn'].OutputValue" \
  --output text --region $REGION)

TASK_DEF_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${PROJECT}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='TaskDefinitionArn'].OutputValue" \
  --output text --region $REGION)

APP_NAME="${ENV}-${PROJECT}-cd-app"
DG_NAME="${ENV}-${PROJECT}-dg"

# === 1. taskdef.json を生成 ===
mkdir -p deploy
echo "📄 taskdef.json を生成中..."
cat > deploy/taskdef.json <<EOF
{
  "family": "${TASK_NAME}",
  "executionRoleArn": "${TASK_EXEC_ROLE}",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "${CONTAINER_NAME}",
      "image": "${ECR_REPO}:${IMAGE_TAG}",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "secrets": [
        {
          "name": "APP_SECRET",
          "valueFrom": "${SECRET_ARN}"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${LOG_GROUP}",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "app"
        }
      },
      "essential": true
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512"
}
EOF

# === 2. appspec.yaml を生成 ===
echo "📄 appspec.yaml を生成中..."
cat > deploy/appspec.yaml <<EOF
version: "1"
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: ${TASK_DEF_ARN}
        LoadBalancerInfo:
          ContainerName: ${CONTAINER_NAME}
          ContainerPort: 8080
EOF

# === 3. zip化して S3 へアップロード ===
echo "🗜️ Zip にまとめて S3 にアップロード..."
cd deploy
rm -f bundle.zip
zip bundle.zip appspec.yaml taskdef.json > /dev/null
aws s3 cp bundle.zip s3://${S3_BUCKET}/${S3_KEY} --region "$REGION"
cd ..

# === 4. デプロイ実行 ===
echo "🚀 CodeDeploy デプロイ作成中..."
DEPLOY_ID=$(aws deploy create-deployment \
  --application-name ${APP_NAME} \
  --deployment-group-name ${DG_NAME} \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --s3-location bucket=${S3_BUCKET},key=${S3_KEY},bundleType=zip \
  --region $REGION \
  --query "deploymentId" \
  --output text)

echo "✅ デプロイ作成完了: $DEPLOY_ID"
echo "🔗 https://${REGION}.console.aws.amazon.com/codedeploy/home?region=${REGION}#/deployments/${DEPLOY_ID}"
