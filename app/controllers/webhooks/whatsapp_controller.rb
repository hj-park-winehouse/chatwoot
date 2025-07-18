class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  def process_payload
    # Log all incoming WhatsApp webhook data
    Rails.logger.info("WhatsApp Webhook Raw Data: #{params.to_unsafe_hash}")
    
    # Forward data to external server if error codes present OR status is "read"
    error_codes = should_forward_webhook?(params.to_unsafe_hash)
    if error_codes
      forward_webhook_data(params.to_unsafe_hash, error_codes[:error_codes], error_codes[:reason])
    else
      Rails.logger.info("WhatsApp webhook not forwarded - no error codes or read status found")
    end
    
    if inactive_whatsapp_number?
      Rails.logger.warn("Rejected webhook for inactive WhatsApp number: #{params[:phone_number]}")
      render json: { error: 'Inactive WhatsApp number' }, status: :unprocessable_entity
      return
    end

    Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def should_forward_webhook?(webhook_data)
    # Forward webhook data if error codes present OR status is "read"
    return nil unless webhook_data.dig('entry').is_a?(Array)

    all_error_codes = []
    has_read_status = false

    webhook_data['entry'].each do |entry|
      next unless entry.dig('changes').is_a?(Array)

      entry['changes'].each do |change|
        next unless change.dig('value', 'statuses').is_a?(Array)

        change['value']['statuses'].each do |status|
          # Check for read status
          if status['status'] == 'read'
            has_read_status = true
            Rails.logger.info("Found 'read' status - will forward webhook data")
          end

          # Check for error codes
          if status.dig('errors').is_a?(Array)
            error_codes = status['errors'].map { |error| error['code'] }.compact
            all_error_codes.concat(error_codes) if error_codes.any?
          end
        end
      end
    end

    # Return result if either condition is met
    unique_error_codes = all_error_codes.uniq
    
    if unique_error_codes.any?
      Rails.logger.info("Found error codes: #{unique_error_codes.join(', ')} - will forward webhook data")
      return { error_codes: unique_error_codes, reason: 'error_detected' }
    elsif has_read_status
      Rails.logger.info("Found 'read' status - will forward webhook data")
      return { error_codes: [], reason: 'read_status_detected' }
    else
      Rails.logger.info("No error codes or read status found - will not forward webhook data")
      return nil
    end
  end

  def forward_webhook_data(webhook_data, error_codes, reason)
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
    
    # 여러 방법으로 데이터 전달 가능
    # 1. HTTP POST (현재 구현 - 가장 안정적)
    # forward_via_rest_client(enhanced_webhook_data)
    
    forwarder = WhatsappWebhookForwarderService.new(enhanced_webhook_data)
    # 2. 다른 방법들 (필요시 주석 해제)
    # forwarder = WhatsappWebhookForwarderService.new(enhanced_webhook_data)
    forwarder.forward_via_http      # Net::HTTP 사용
    # forwarder.forward_via_websocket # WebSocket 사용 (추가 gem 필요)

    #forwarder.forward_via_tcp       # TCP Socket 사용
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
