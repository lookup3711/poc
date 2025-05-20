#!/bin/bash
set -euo pipefail

# ✅ プロジェクトルートから実行されているかチェック
if [[ ! -f "scripts/2-deploy-alb.sh" ]]; then
  echo "❌ Please run this script from the project root (e.g., ./scripts/2-deploy-alb.sh)"
  exit 1
fi

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# 環境設定
source ./env/${ENV}.env
TEMPLATE_DIR="cloudformation/network"

# 出力取得関数
stack_output() {
  aws cloudformation describe-stacks \
    --stack-name "$1" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" \
    --output text \
    --region "$REGION"
}

# 指定したドメインに対応する ACM 証明書の ARN を取得する
get_acm_cert_arn() {
  local domain=$1
  aws acm list-certificates \
    --region "$REGION" \
    --query "CertificateSummaryList[?DomainName=='${domain}'].CertificateArn" \
    --output text
}

# ドメイン名に対応するACM証明書ARNを取得
ACM_CERT_ARN=$(get_acm_cert_arn "$FQDN")

# バリデーション
if [[ -z "$ACM_CERT_ARN" ]]; then
  echo "❌ ACM 証明書がドメイン [$FQDN] に対して見つかりません"
  exit 1
fi

# 各リソースID取得
VPC_ID=$(stack_output "${ENV}-${PROJECT}-vpc" VpcId)
PUB1_ID=$(stack_output "${ENV}-${PROJECT}-vpc" SubnetPublic1)
PUB2_ID=$(stack_output "${ENV}-${PROJECT}-vpc" SubnetPublic2)
ALB_SG=$(stack_output "${ENV}-${PROJECT}-sg" AlbSecurityGroup)

# ポートと証明書
CONTAINER_PORT=8080

# デプロイ
echo "▶️ ALBスタックを作成中..."
aws cloudformation deploy \
  --template-file ${TEMPLATE_DIR}/alb.yml \
  --stack-name ${ENV}-${PROJECT}-alb \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    VpcId=$VPC_ID \
    SubnetPublic1Id=$PUB1_ID \
    SubnetPublic2Id=$PUB2_ID \
    AlbSecurityGroup=$ALB_SG \
    TargetPort=$CONTAINER_PORT \
    ACMCertificateArn="$ACM_CERT_ARN" \
  --region $REGION

echo "✅ ALBスタック作成完了"
