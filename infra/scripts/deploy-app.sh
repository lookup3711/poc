#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd] [IMAGE_TAG]"
  exit 1
fi

# === 初期変数設定 ===
source ./env/${ENV}.env
IMAGE_TAG="${2:-init}"
S3_KEY="${ENV}-${PROJECT}/${IMAGE_TAG}/bundle.zip"

mkdir -p "$WORK_DIR"

echo "🔍 CloudFormation Output から各種リソースを取得中..."

ECR_REPO=$(aws cloudformation describe-stacks \
  --stack-name "${ENV}-${PROJECT}-ecr" \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" \
  --output text --region "$REGION")

TASK_EXEC_ROLE=$(aws cloudformation describe-stacks \
  --stack-name "${ENV}-${PROJECT}-ecs" \
  --query "Stacks[0].Outputs[?OutputKey=='ECSTaskExecutionRoleArn'].OutputValue" \
  --output text --region "$REGION")

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" \
  --query "ARN" \
  --output text)

RDS_SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${ENV}-${PROJECT}-rds-bastion" \
  --query "Stacks[0].Outputs[?OutputKey=='RDSSecretArn'].OutputValue" \
  --output text)

# === 1. taskdef.json を生成 ===
echo "📄 taskdef.json を生成中..."
cat > "$WORK_DIR/taskdef.json" <<EOF
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
          "containerPort": ${CONTAINER_PORT},
          "protocol": "tcp"
        }
      ],
      "environment": [
          {
              "name": "ENV",
              "value": "${ENV}"
          },
          {
              "name": "APP_VERSION",
              "value": "${IMAGE_TAG}"
          }
      ],
      "secrets": [
          {
              "name": "POSTGRES_HOST",
              "valueFrom": "${SECRET_ARN}:POSTGRES_HOST::"
          },
          {
              "name": "POSTGRES_PORT",
              "valueFrom": "${SECRET_ARN}:POSTGRES_PORT::"
          },
          {
              "name": "POSTGRES_USER",
              "valueFrom": "${RDS_SECRET_ARN}:username::"
          },
          {
              "name": "POSTGRES_PASSWORD",
              "valueFrom": "${RDS_SECRET_ARN}:password::"
          },
          {
              "name": "POSTGRES_DB",
              "valueFrom": "${SECRET_ARN}:POSTGRES_DB::"
          }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${LOG_GROUP}",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "essential": true
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "${CONTAINER_CPU}",
  "memory": "${CONTAINER_MEMORY}"
}
EOF

# === 2. タスク定義を ECS に登録 ===
echo "📤 タスク定義を ECS に登録中..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://"$WORK_DIR/taskdef.json" \
  --region "$REGION" \
  --query "taskDefinition.taskDefinitionArn" \
  --output text)

echo "✅ 登録された TaskDefinition ARN: $NEW_TASK_DEF_ARN"

# === 3. appspec.yml を生成 ===
echo "📄 appspec.yml を生成中..."
cat > "$WORK_DIR/appspec.yml" <<EOF
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
cd "$WORK_DIR"
rm -f bundle.zip
zip bundle.zip appspec.yml > /dev/null
aws s3 cp bundle.zip s3://${DEPLOY_BUCKET}/${S3_KEY} --region "$REGION"
cd ..

# === 5. CodeDeploy デプロイ作成 ===
echo "🚀 CodeDeploy によるデプロイを開始します..."
DEPLOY_ID=$(aws deploy create-deployment \
  --application-name "${APP_NAME}" \
  --deployment-group-name "${DG_NAME}" \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --s3-location bucket=${DEPLOY_BUCKET},key=${S3_KEY},bundleType=zip \
  --region "$REGION" \
  --query "deploymentId" \
  --output text)

echo "✅ デプロイ作成完了: $DEPLOY_ID"
echo "🔗 確認用URL: https://${REGION}.console.aws.amazon.com/codedeploy/home?region=${REGION}#/deployments/${DEPLOY_ID}"
