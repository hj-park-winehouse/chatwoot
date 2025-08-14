class Webhooks::TelegramController < ActionController::API
  def process_payload
    Webhooks::TelegramEventsJob.perform_later(params.to_unsafe_hash)
    Rails.logger.info("🤖 Telegram Webhook Raw Data: #{params.to_unsafe_hash}")

    # Forward data to external server if error codes present OR status is "read"
    # error_codes = should_forward_webhook?(params.to_unsafe_hash)
    # if error_codes
    #   Rails.logger.info("📤 Telegram webhook will be forwarded - Reason: #{error_codes[:reason]}, Error codes: #{error_codes[:error_codes]}")
    #   forward_webhook_data(params.to_unsafe_hash, error_codes[:error_codes], error_codes[:reason])
    # else
    #   Rails.logger.info('🚫 Telegram webhook not forwarded - no error codes or read status found')
    # end

    # head :ok
  end

  private

  def forward_webhook_data(webhook_data, error_codes, reason)
    Rails.logger.info('🔄 Starting Telegram webhook forwarding process...')
    Rails.logger.info("📋 Forwarding details - Reason: #{reason}, Error codes: #{error_codes}, Data size: #{webhook_data.to_json.bytesize} bytes")

    # Add error_codes and metadata to webhook_data
    enhanced_webhook_data = webhook_data.deep_dup
    enhanced_webhook_data['error_codes'] = error_codes
    enhanced_webhook_data['chatwoot_metadata'] = {
      'forwarded_at' => Time.current.iso8601,
      'detected_error_codes' => error_codes,
      'total_error_count' => error_codes.length,
      'has_errors' => error_codes.any?,
      'forwarding_reason' => reason
    }

    Rails.logger.info("📦 Enhanced webhook data prepared, total size: #{enhanced_webhook_data.to_json.bytesize} bytes")

    # 여러 방법으로 데이터 전달 가능
    # 1. HTTP POST (현재 구현 - 가장 안정적)
    # forward_via_rest_client(enhanced_webhook_data)

    Rails.logger.info('🌐 Initializing TelegramWebhookForwarderService...')
    forwarder = TelegramWebhookForwarderService.new(enhanced_webhook_data)

    Rails.logger.info('🚀 Starting HTTP forwarding to partner.ttgo.dev:5012...')
    # 2. 다른 방법들 (필요시 주석 해제)
    # forwarder = TelegramWebhookForwarderService.new(enhanced_webhook_data)
    forwarder.forward_via_http      # Net::HTTP 사용
    # forwarder.forward_via_websocket # WebSocket 사용 (추가 gem 필요)

    #forwarder.forward_via_tcp       # TCP Socket 사용
    Rails.logger.info('✅ Telegram webhook forwarding process completed')
  end

  def should_forward_webhook?(webhook_data)
    error_codes = extract_error_codes(webhook_data)
    read_status = webhook_data.dig('message', 'status') == 'read'

    Rails.logger.info('🔍 Checking webhook forwarding conditions...')
    Rails.logger.info("   📊 Error codes found: #{error_codes}")
    Rails.logger.info("   📖 Read status detected: #{read_status}")
    Rails.logger.info("   🔗 Message status value: #{webhook_data.dig('message', 'status')}")

    # Always forward Telegram webhooks (unlike WhatsApp which only forwards on errors/read status)
    reason = if error_codes.present?
               'Error codes present'
             elsif read_status
               'Message read'
             else
               'Standard webhook forwarding'
             end

    result = { error_codes: error_codes, reason: reason }
    Rails.logger.info("✅ Webhook forwarding conditions met: #{result}")
    result
  end

  def extract_error_codes(_webhook_data)
    # Telegram 웹훅 구조에 맞게 에러 코드 추출
    []

    # Telegram webhook doesn't have the same structure as WhatsApp
    # Add logic here if Telegram sends error codes in a specific format
    # For now, return empty array
  end
end
