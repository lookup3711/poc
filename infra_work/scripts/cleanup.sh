#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# 出力を less などに渡さないようにする
export AWS_PAGER=""

# === 設定 ===
source ./env/${ENV}.env

# === ECS サービス停止・削除 ===
echo "🛑 ECS サービスを停止＆削除します（${SERVICE_NAME}）"

# DesiredCount を 0 に更新
echo "🔻 Updating desired count to 0..."
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --desired-count 0 \
  --region "$REGION" || echo "⚠️ サービスが見つからないか既に削除済み"

# タスクが停止するのを待機（10秒）
echo "⏱️ 停止待機中..."
sleep 10

# サービス削除（force 付き）
echo "🗑️ Deleting ECS service..."
aws ecs delete-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --force \
  --region "$REGION" || echo "⚠️ サービスが見つからないか既に削除済み"

# === ECR リポジトリ削除 ===
echo "🗑️ Deleting ECR repository: $ECR_REPO_NAME"
aws ecr delete-repository \
  --repository-name "$ECR_REPO_NAME" \
  --force \
  --region "$REGION" || echo "⚠️ ECR repository not found or already deleted"

# === CloudFormation stacks の削除 ===
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

# === SecretsManager シークレット削除 ===
echo "🗝️ Deleting secret: $SECRET_NAME"
aws secretsmanager delete-secret \
  --secret-id "$SECRET_NAME" \
  --force-delete-without-recovery \
  --region "$REGION" || echo "⚠️ Secret not found or already deleted"

# === CloudWatch Logs 削除 ===
echo "📋 Deleting CloudWatch Logs group: $LOG_GROUP"
aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" || echo "⚠️ Log group not found or already deleted"

echo "✅ クリーンアップ完了"
