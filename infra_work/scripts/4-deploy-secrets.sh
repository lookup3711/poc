#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# === 設定読込（SECRET_NAME など）
source ./env/${ENV}.env

STACK_NAME="${ENV}-${PROJECT}-secrets"
TEMPLATE_PATH="cloudformation/secrets/secrets.yml"
OUTPUT_TEMPLATE_PATH="cloudformation/secrets/secrets-outputs.yml"

echo "🔍 Checking for secret: $SECRET_NAME"
echo "🔍 Checking for stack:  $STACK_NAME"

# === シークレット存在確認 ===
SECRET_EXISTS=false
if aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" > /dev/null 2>&1; then
  SECRET_EXISTS=true
  echo "✅ Secret exists: $SECRET_NAME"
fi

# === スタック存在確認 ===
STACK_EXISTS=false
if aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" > /dev/null 2>&1; then
  STACK_EXISTS=true
  echo "✅ Stack exists: $STACK_NAME"
fi

# === パターン1: Secret がない → secrets.yml で作成
if [ "$SECRET_EXISTS" = false ]; then
  echo "🔐 Secret does not exist. Creating it via secrets.yml..."
  aws cloudformation deploy \
    --template-file "$TEMPLATE_PATH" \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
      Environment="$ENV" \
      ProjectName="$PROJECT" \
      SecretName="$SECRET_NAME"

  echo "⏳ Waiting for secret to be available..."
  until aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" > /dev/null 2>&1; do
    sleep 2
  done

  echo "📝 Setting initial secret value..."
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" \
    --secret-string '{"INIT": "init_value"}'

  echo "✅ secrets.yml stack created successfully"
  exit 0
fi

# === パターン2: Secret はあるが Stack がない → secrets-outputs.yml で補完
if [ "$SECRET_EXISTS" = true ] && [ "$STACK_EXISTS" = false ]; then
  echo "📦 Stack not found. Creating outputs-only stack from secrets-outputs.yml..."

  SECRET_ARN=$(aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" \
    --query "ARN" \
    --output text)

  aws cloudformation deploy \
    --template-file "$OUTPUT_TEMPLATE_PATH" \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --parameter-overrides \
      Environment="$ENV" \
      ProjectName="$PROJECT" \
      SecretArn="$SECRET_ARN"

  echo "✅ secrets-outputs.yml stack created successfully"
else
  echo "✅ No action needed. Secret and stack are already present."
fi
