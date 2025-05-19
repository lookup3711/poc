#!/bin/bash
set -euo pipefail

# === 設定 ===
ENV="dev"
PROJECT="cmssoel"
REGION="ap-northeast-1"
STACK_NAME="${ENV}-${PROJECT}-secrets"
TEMPLATE_PATH="cloudformation/secrets/secrets-outputs.yaml"

# === 既存シークレット名を組み立て ===
SECRET_NAME="${PROJECT}-${ENV}"

echo "🔍 Checking for secret [${SECRET_NAME}]..."

# === シークレットの存在確認 ===
if ! aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" > /dev/null 2>&1; then
  echo "❌ Secret '${SECRET_NAME}' does not exist in region ${REGION}."
  echo "ℹ️  Please create the secret manually or via CloudFormation before continuing."
  
  # === CloudFormationテンプレートをデプロイ ===
  echo "🚀 Deploying secrets stack from cloudformation/secrets/secrets.yaml..."
  aws cloudformation deploy \
    --template-file "cloudformation/secrets/secrets.yaml" \
    --stack-name "${STACK_NAME}" \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides Environment="$ENV" ProjectName="$PROJECT"

  echo "⏳ Waiting for secret creation to complete..."
  # Wait until the secret becomes available
  until aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" > /dev/null 2>&1; do
    sleep 2
  done

  # === 初期値を put-secret-value で登録 ===
  echo "📝 Setting initial value in secret: $SECRET_NAME"
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" \
    --secret-string '{"INIT": "init_value"}'
  
  exit 0
fi

# === ARN 取得 ===
SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" \
  --query "ARN" \
  --output text)

echo "✅ Found secret: $SECRET_ARN"

# === CloudFormation スタック存在確認 ===
if aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" > /dev/null 2>&1; then
  echo "🔄 Updating existing stack: $STACK_NAME"
else
  echo "📦 Creating new stack: $STACK_NAME"
fi

# === CloudFormation デプロイ ===
aws cloudformation deploy \
  --template-file "$TEMPLATE_PATH" \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --parameter-overrides \
    Environment="$ENV" \
    ProjectName="$PROJECT" \
    SecretArn="$SECRET_ARN"

echo "✅ Secret outputs stack deployed: $STACK_NAME"
