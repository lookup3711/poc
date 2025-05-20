#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# 設定を読み込み
source ./env/${ENV}.env

# === ALB の DNS名とゾーンIDを取得 ===
ALB_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${ENV}-${PROJECT}-alb" \
  --query "Stacks[0].Outputs[?OutputKey=='AlbArn'].OutputValue" \
  --output text)

ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" \
  --output text)

ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].CanonicalHostedZoneId" \
  --output text)

# === Route 53 ゾーンIDを取得 ===
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${ZONE_NAME}." \
  --query "HostedZones[?Name=='${ZONE_NAME}.'].Id" \
  --output text | sed 's|/hostedzone/||')

if [[ -z "$ZONE_ID" ]]; then
  echo "❌ ZONE_ID が取得できませんでした（ZONE_NAME=${ZONE_NAME}）"
  exit 1
fi

# === Aレコード作成 ===
echo "✅ Creating A record for ${FQDN} → ${ALB_DNS_NAME}"

aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch '{
    "Comment": "Alias for ALB",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "'"${FQDN}"'",
          "Type": "A",
          "AliasTarget": {
            "HostedZoneId": "'"${ALB_ZONE_ID}"'",
            "DNSName": "'"${ALB_DNS_NAME}"'",
            "EvaluateTargetHealth": false
          }
        }
      }
    ]
  }'
