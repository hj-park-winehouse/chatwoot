token="7305214835:AAHg1aeB_3p2kPuq1hXNqUdSYGEBuzYxalQ"
url="https://telegram.ttgo.dev"
webhook_url="${url}/webhooks/telegram/${token}"

# curl

curl -X GET "https://api.telegram.org/bot${token}/setWebhook" -d "url=${webhook_url}"

# https://api.telegram.org/bot7305214835:AAHg1aeB_3p2kPuq1hXNqUdSYGEBuzYxalQ/setWebhook?url=https://8bdc86fd9b54.ngrok-free.app/webhooks/telegram/7305214835:AAHg1aeB_3p2kPuq1hXNqUdSYGEBuzYxalQ
