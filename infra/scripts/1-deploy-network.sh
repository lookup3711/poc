#!/bin/bash
set -euo pipefail

# ✅ 実行ディレクトリチェック
if [[ ! -f "scripts/1-deploy-network.sh" ]]; then
  echo "❌ Please run this script from the project root (e.g., ./scripts/1-deploy-network.sh)"
  exit 1
fi

# === 引数処理 ===
ENV="${1:-xxx}"  # 引数がなければ "xxx" をダミーとして使用
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
  echo "❌ 使用方法: $0 [dev|prd]"
  exit 1
fi

# 📌 環境変数
source ./env/${ENV}.env
TEMPLATE_DIR="cloudformation/network"

# ✅ CloudFormation の Output を取得する関数
stack_output() {
  aws cloudformation describe-stacks \
    --stack-name "$1" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" \
    --output text \
    --region "$REGION"
}

echo "▶️ 1. VPC スタック作成"
aws cloudformation deploy \
  --template-file ${TEMPLATE_DIR}/vpc.yml \
  --stack-name ${ENV}-${PROJECT}-vpc \
  --parameter-overrides Environment=$ENV ProjectName=$PROJECT \
  --region $REGION

echo "⏳ VPC スタック完了待ち..."
aws cloudformation wait stack-create-complete \
  --stack-name ${ENV}-${PROJECT}-vpc \
  --region $REGION

# VPC Output 取得
VPC_ID=$(stack_output "${ENV}-${PROJECT}-vpc" VpcId)
VPC_CIDR=$(stack_output "${ENV}-${PROJECT}-vpc" VpcCidrBlock)
PUB1_ID=$(stack_output "${ENV}-${PROJECT}-vpc" SubnetPublic1)
PUB2_ID=$(stack_output "${ENV}-${PROJECT}-vpc" SubnetPublic2)
PRV1_ID=$(stack_output "${ENV}-${PROJECT}-vpc" SubnetPrivate1)
PRV2_ID=$(stack_output "${ENV}-${PROJECT}-vpc" SubnetPrivate2)

echo "▶️ 2. IGW/NAT スタック作成"
aws cloudformation deploy \
  --template-file ${TEMPLATE_DIR}/igw_nat.yml \
  --stack-name ${ENV}-${PROJECT}-igw-nat \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    VpcId=$VPC_ID \
    SubnetPublic1Id=$PUB1_ID \
  --region $REGION

echo "⏳ IGW/NAT スタック完了待ち..."
aws cloudformation wait stack-create-complete \
  --stack-name ${ENV}-${PROJECT}-igw-nat \
  --region $REGION

# IGW/NAT Output 取得
IGW_ID=$(stack_output "${ENV}-${PROJECT}-igw-nat" InternetGatewayId)
NAT_ID=$(stack_output "${ENV}-${PROJECT}-igw-nat" NatGatewayId)

echo "▶️ 3. Route Table スタック作成"
aws cloudformation deploy \
  --template-file ${TEMPLATE_DIR}/route_tables.yml \
  --stack-name ${ENV}-${PROJECT}-routes \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    VpcId=$VPC_ID \
    InternetGatewayId=$IGW_ID \
    NatGatewayId=$NAT_ID \
    SubnetPublic1Id=$PUB1_ID \
    SubnetPublic2Id=$PUB2_ID \
    SubnetPrivate1Id=$PRV1_ID \
    SubnetPrivate2Id=$PRV2_ID \
  --region $REGION

echo "▶️ 4. Security Group スタック作成"
aws cloudformation deploy \
  --template-file ${TEMPLATE_DIR}/sg.yml \
  --stack-name ${ENV}-${PROJECT}-sg \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    VpcId=$VPC_ID \
    VpcCidrBlock=$VPC_CIDR \
  --region $REGION

echo "✅ ネットワーク関連のスタック作成が完了しました"

echo "▶️ 5. VPC Endpoint スタック作成"

# 必要な Output を取得
PRIVATE_RT_ID=$(stack_output "${ENV}-${PROJECT}-routes" PrivateRouteTableId)
VPCE_SG_ID=$(stack_output "${ENV}-${PROJECT}-sg" VpcEndpointSecurityGroup)

aws cloudformation deploy \
  --template-file ${TEMPLATE_DIR}/vpc_endpoint.yml \
  --stack-name ${ENV}-${PROJECT}-vpce \
  --parameter-overrides \
    Environment=$ENV \
    ProjectName=$PROJECT \
    VpcId=$VPC_ID \
    SubnetPublic1Id=$PUB1_ID \
    SubnetPublic2Id=$PUB2_ID \
    PrivateRouteTableId=$PRIVATE_RT_ID \
    VpcEndpointSG=$VPCE_SG_ID \
  --region $REGION

echo "✅ VPCエンドポイントスタックの作成が完了しました"
