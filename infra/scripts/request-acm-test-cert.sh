#!/bin/bash
set -euo pipefail

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# === 設定 ===
source ./env/${ENV}.env
PURPOSE="test"

# === 1. ドメイン名を組み立てる ===
echo "📌 リクエスト対象のドメイン: ${FQDN}"

# === 2. 証明書をリクエスト ===
CERT_ARN=$(aws acm request-certificate \
  --domain-name "$FQDN" \
  --validation-method DNS \
  --idempotency-token "${PURPOSE}${ENV}" \
  --region "$REGION" \
  --output text \
  --query CertificateArn)

echo "✅ 証明書リクエスト完了: ${CERT_ARN}"

# === 3. 検証用 CNAME を取得 ===
echo "⏳ CNAME 検証レコードを取得中..."
sleep 5  # 反映待ち

read NAME TYPE VALUE <<<$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord.[Name, Type, Value]" \
  --output text)

echo "✅ CNAMEレコード: ${NAME} ${TYPE} ${VALUE}"

# === 4. Hosted Zone ID を取得 ===
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$ZONE_NAME" \
  --query "HostedZones[0].Id" \
  --output text | sed 's|/hostedzone/||')

# === 5. CNAME レコードを追加 ===
cat > tmp-cname-record.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${NAME}",
        "Type": "${TYPE}",
        "TTL": 300,
        "ResourceRecords": [
          { "Value": "${VALUE}" }
        ]
      }
    }
  ]
}
EOF

echo "📤 Route 53 に CNAME を追加中..."
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch file://tmp-cname-record.json \
  --region "$REGION"

echo "✅ DNS 検証レコードを追加しました。数分後に ACM が ISSUED 状態になります。"
echo "🔍 ACMステータス確認コマンド:"
echo "aws acm describe-certificate --certificate-arn $CERT_ARN --region $REGION --query 'Certificate.Status'"
