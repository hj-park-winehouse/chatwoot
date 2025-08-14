class TelegramWebhookForwarderService
  require 'net/http'
  require 'json'
  require 'uri'

  def initialize(webhook_data)
    @webhook_data = webhook_data
    # @target_url = 'https://partner.ttgo.dev:5012/telegram-webhook'
    @target_url = 'https://telegram.ttgo.dev:8443/telegram-webhook'
    @error_code = extract_error_code

    Rails.logger.info('🏗️  TelegramWebhookForwarderService initialized')
    Rails.logger.info("   🎯 Target URL: #{@target_url}")
    Rails.logger.info("   📊 Webhook data size: #{@webhook_data.to_json.bytesize} bytes")
    Rails.logger.info("   🔍 Error code: #{@error_code || 'none'}")
  end

  private

  def extract_error_code
    # Extract error code from webhook data for logging
    # Telegram webhook doesn't typically have error codes like WhatsApp
    # For now, return nil
    nil
  end

  public

  def forward_via_http
    Rails.logger.info("🔗 TelegramWebhookForwarderService: Starting HTTP forwarding to #{@target_url}")

    Thread.new do
      start_time = Time.current
      uri = URI(@target_url)

      Rails.logger.info("📡 Setting up HTTP connection to #{uri.host}:#{uri.port}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE # SSL 검증 비활성화
      http.read_timeout = 10
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri.path, {
                                      'Content-Type' => 'application/json',
                                      'User-Agent' => 'Chatwoot-Telegram-Forwarder'
                                    })
      request.body = @webhook_data.to_json

      Rails.logger.info("📤 Sending POST request with #{request.body.bytesize} bytes of data")
      Rails.logger.info("🎯 Target URL: #{@target_url}")
      Rails.logger.info("📋 Headers: #{request.to_hash}")

      response = http.request(request)
      duration = Time.current - start_time

      if response.code.to_i.between?(200, 299)
        Rails.logger.info('✅ Telegram webhook data forwarded successfully via HTTP')
        Rails.logger.info("   📊 Response code: #{response.code}")
        Rails.logger.info("   ⏱️  Duration: #{duration.round(3)}s")
        Rails.logger.info("   📝 Response body: #{response.body.truncate(200)}")
      else
        Rails.logger.warn('❌ Failed to forward Telegram webhook data via HTTP')
        Rails.logger.warn("   📊 Response code: #{response.code}")
        Rails.logger.warn("   💬 Response message: #{response.message}")
        Rails.logger.warn("   📝 Response body: #{response.body.truncate(200)}")
        Rails.logger.warn("   ⏱️  Duration: #{duration.round(3)}s")
      end
    rescue StandardError => e
      Rails.logger.error("💥 Error forwarding Telegram webhook data via HTTP: #{e.class.name}: #{e.message}")
      Rails.logger.error("📍 Backtrace: #{e.backtrace.first(3).join(' | ')}")
    end
  end
end
