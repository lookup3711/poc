# インフラデプロイ手順

## 事前準備
### 作業用アカウント
- aws-cli を使用できる環境
  - 適切なcredentialなどが設定されていること
  - Admin権限で動作を確認済

※要各自設定

### 環境変数の設定
- infra/env/{ENV}.env を埋める
※ 2025/05/21 現在 dev.env と prd.env を仮作成済

### ROUTE53まわり
- ホストゾーンがすでに存在すること
- ACM が各 FQDN について作成済であること
  - ない場合は下記手順で作成する
```bash
cd infra
./script/request-acm-test-cert.sh [dev|prd]
```

※ 2025/05/21 現在 dev.cmssoel.click と cmssoel.click の証明書が作成済

### 環境周り
- deploy用のバケットがあること
  - cmssoel-deploy-bucket を想定
- ない場合は下記で作成する
  - aws s3 mb s3://cmssoel-deploy-artifacts --region ap-northeast-1

※ 2025/05/21 現在作成済。 バケット名は env/ のファイルにも影響する

## インフラ作成スクリプトの実行
```bash
cd infra
./script/#-deploy-all.sh [dev|prd]
```

## インフラ削除手順
※ ECR内のイメージやsecretもすべて削除するため、注意する
※ スタックが中途半端に残ってしまうことがある。その場合は再び実行する
```bash
cd infra
./script/cleanup.sh [dev|prd]
```

# アプリデプロイ手順
```bash
cd infra
./script/6-push-image.sh [dev|prd] [タグ名]
./script/deploy-app.sh [dev|prd] [タグ名（上と同じもの）]
```

