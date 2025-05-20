# Conoha ドメインを使用する
aws route53 create-hosted-zone \
  --name sarukani.site \
  --caller-reference $(date +%s)

返却される下記のような値をConohaに登録
"NameServers": [
  "ns-123.awsdns-45.com",
  "ns-456.awsdns-67.net",
  "ns-789.awsdns-89.org",
  "ns-012.awsdns-10.co.uk"
]
