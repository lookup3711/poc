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

# === シークレット存在確認 ===
echo "🔍 シークレットを探しています...: $SECRET_NAME"

SECRET_EXISTS=false
if aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" > /dev/null 2>&1; then
  SECRET_EXISTS=true
  echo "✅ シークレットはすでに存在しています: $SECRET_NAME"
  exit 0
fi

if [ "$SECRET_EXISTS" = false ]; then
  echo "🔐 シークレットが存在しないため、作成します"
  
  # 固定値（後ほど上書き可能）
  # TODO: .env など、github にアップしないファイルから読み込む
  SECRET_JSON=$(jq -n \
    --arg gcid "" \
    --arg gcsec "" \
    --arg port "5432" \
    --arg db "postgres" \
    --arg host "" \
    '{
      GOOGLE_CLIENT_ID: $gcid,
      GOOGLE_CLIENT_SECRET: $gcsec,
      POSTGRES_PORT: $port,
      POSTGRES_DB: $db,
      POSTGRES_HOST: $host
    }'
  )

  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --secret-string "$SECRET_JSON" \
    --region "$REGION"

  echo "✅ シークレットを新規に作成しました: $SECRET_NAME"
fi
