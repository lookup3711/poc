#!/bin/bash
set -euo pipefail

# === 初期変数設定 ===
ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_TAG="${1:-latest}"

TASK_NAME="${ENV}-${PROJECT}-task"
CONTAINER_NAME="${ENV}-${PROJECT}-app"
LOG_GROUP="/ecs/${ENV}-${PROJECT}"
S3_BUCKET="codeploy-bundles"
S3_KEY="${ENV}-${PROJECT}/${IMAGE_TAG}/bundle.zip"
DEPLOY_DIR="deploy"

APP_NAME="${ENV}-${PROJECT}-cd-app"
DG_NAME="${ENV}-${PROJECT}-dg"

mkdir -p "$DEPLOY_DIR"

echo "🔍 CloudFormation Output から各種リソースを取得中..."

ECR_REPO=$(aws cloudformation describe-stacks \
  --stack-name "${ENV}-${PROJECT}-ecr" \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" \
  --output text --region "$REGION")

TASK_EXEC_ROLE=$(aws cloudformation describe-stacks \
  --stack-name "${ENV}-${PROJECT}-ecs" \
  --query "Stacks[0].Outputs[?OutputKey=='ECSTaskExecutionRoleArn'].OutputValue" \
  --output text --region "$REGION")

SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${ENV}-${PROJECT}-secrets" \
  --query "Stacks[0].Outputs[?OutputKey=='SecretArn'].OutputValue" \
  --output text --region "$REGION")

# === 1. taskdef.json を生成 ===
echo "📄 taskdef.json を生成中..."
cat > "$DEPLOY_DIR/taskdef.json" <<EOF
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

# === 2. タスク定義を ECS に登録 ===
echo "📤 タスク定義を ECS に登録中..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://"$DEPLOY_DIR/taskdef.json" \
  --region "$REGION" \
  --query "taskDefinition.taskDefinitionArn" \
  --output text)

echo "✅ 登録された TaskDefinition ARN: $NEW_TASK_DEF_ARN"

# === 3. appspec.yml を生成 ===
echo "📄 appspec.yml を生成中..."
cat > "$DEPLOY_DIR/appspec.yml" <<EOF
version: "1"
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: ${NEW_TASK_DEF_ARN}
        LoadBalancerInfo:
          ContainerName: ${CONTAINER_NAME}
          ContainerPort: 8080
EOF

# === 4. zip化して S3 へアップロード ===
echo "🗜️ appspec.yml を zip にまとめて S3 にアップロード..."
cd "$DEPLOY_DIR"
rm -f bundle.zip
zip bundle.zip appspec.yml > /dev/null
aws s3 cp bundle.zip s3://${S3_BUCKET}/${S3_KEY} --region "$REGION"
cd ..

# === 5. CodeDeploy デプロイ作成 ===
echo "🚀 CodeDeploy によるデプロイを開始します..."
DEPLOY_ID=$(aws deploy create-deployment \
  --application-name "${APP_NAME}" \
  --deployment-group-name "${DG_NAME}" \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --s3-location bucket=${S3_BUCKET},key=${S3_KEY},bundleType=zip \
  --region "$REGION" \
  --query "deploymentId" \
  --output text)

echo "✅ デプロイ作成完了: $DEPLOY_ID"
echo "🔗 確認用URL: https://${REGION}.console.aws.amazon.com/codedeploy/home?region=${REGION}#/deployments/${DEPLOY_ID}"
