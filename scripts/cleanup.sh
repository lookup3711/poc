#!/bin/bash
set -euo pipefail

# 環境変数
ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"
SECRET_NAME="${PROJECT}-${ENV}"
ECR_REPO_NAME="${ENV}-${PROJECT}"
LOG_GROUP="/ecs/${ENV}-${PROJECT}"

# 削除対象スタック（依存順で後ろから削除）
STACKS=(
  "${ENV}-${PROJECT}-codedeploy"
  "${ENV}-${PROJECT}-ecs-service"
  "${ENV}-${PROJECT}-ecs"
  "${ENV}-${PROJECT}-ecr"
  "${ENV}-${PROJECT}-secrets"
  "${ENV}-${PROJECT}-alb"
  "${ENV}-${PROJECT}-vpce"
  "${ENV}-${PROJECT}-sg"
  "${ENV}-${PROJECT}-routes"
  "${ENV}-${PROJECT}-igw-nat"
  "${ENV}-${PROJECT}-vpc"
)

echo "▶️ CloudFormation stacks を削除中..."
for stack in "${STACKS[@]}"; do
  echo "🧹 Deleting stack: $stack"
  aws cloudformation delete-stack --stack-name "$stack" --region "$REGION"
done

echo "⏳ スタックの削除を待機（任意で監視を推奨）"

# SecretsManager シークレット削除
echo "🗝️ Deleting secret: $SECRET_NAME"
aws secretsmanager delete-secret \
  --secret-id "$SECRET_NAME" \
  --force-delete-without-recovery \
  --region "$REGION" || echo "⚠️ Secret not found or already deleted"

# CloudWatch Logs 削除
echo "📋 Deleting CloudWatch Logs group: $LOG_GROUP"
aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" || echo "⚠️ Log group not found or already deleted"

# ECR リポジトリ削除
echo "🗑️ Deleting ECR repository: $ECR_REPO_NAME"
aws ecr delete-repository \
  --repository-name "$ECR_REPO_NAME" \
  --force \
  --region "$REGION" || echo "⚠️ ECR repository not found or already deleted"

echo "✅ クリーンアップ完了"
