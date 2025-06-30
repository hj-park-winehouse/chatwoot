class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  def process_payload
    # Log all incoming WhatsApp webhook data
    Rails.logger.info("WhatsApp Webhook Raw Data: #{params.to_unsafe_hash}")
    
    # Forward data to external server
    forward_webhook_data(params.to_unsafe_hash)
    
    if inactive_whatsapp_number?
      Rails.logger.warn("Rejected webhook for inactive WhatsApp number: #{params[:phone_number]}")
      render json: { error: 'Inactive WhatsApp number' }, status: :unprocessable_entity
      return
    end

    Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def forward_webhook_data(webhook_data)
    # 여러 방법으로 데이터 전달 가능
    # 1. HTTP POST (현재 구현 - 가장 안정적)
    # forward_via_rest_client(webhook_data)
    
    # 2. 다른 방법들 (필요시 주석 해제)
    # forwarder = WhatsappWebhookForwarderService.new(webhook_data)
    # forwarder.forward_via_http      # Net::HTTP 사용
    # forwarder.forward_via_websocket # WebSocket 사용 (추가 gem 필요)
    forwarder = WhatsappWebhookForwarderService.new(webhook_data)

    forwarder.forward_via_tcp       # TCP Socket 사용
  end

  def forward_via_rest_client(webhook_data)
    # Forward webhook data to external server asynchronously using RestClient
    Thread.new do
      begin
        response = RestClient.post(
          'https://partner.ttgo.dev:5010/whatsapp-webhook',
          webhook_data.to_json,
          {
            content_type: :json,
            accept: :json,
            user_agent: 'Chatwoot-WhatsApp-Forwarder',
            timeout: 10,
            verify_ssl: false # SSL 인증서 검증 비활성화 (필요시)
          }
        )
        
        Rails.logger.info("WhatsApp webhook data forwarded successfully to partner.ttgo.dev:5010 - Response: #{response.code}")
      rescue RestClient::Exception => e
        Rails.logger.warn("Failed to forward WhatsApp webhook data: #{e.response&.code} - #{e.message}")
      rescue StandardError => e
        Rails.logger.error("Error forwarding WhatsApp webhook data: #{e.message}")
      end
    end
  rescue StandardError => e
    Rails.logger.error("Error creating thread for webhook forwarding: #{e.message}")
  end

  def valid_token?(token)
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end

  def inactive_whatsapp_number?
    phone_number = params[:phone_number]
    return false if phone_number.blank?

    inactive_numbers = GlobalConfig.get_value('INACTIVE_WHATSAPP_NUMBERS').to_s
    return false if inactive_numbers.blank?

    inactive_numbers_array = inactive_numbers.split(',').map(&:strip)
    inactive_numbers_array.include?(phone_number)
  end
end
