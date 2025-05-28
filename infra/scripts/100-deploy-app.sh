#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi
TAG="${2:-init}"

./scripts/push-image.sh ${ENV} ${TAG}

./scripts/deploy-app.sh ${ENV} ${TAG}

echo "✅ アプリのデプロイを開始しました"
