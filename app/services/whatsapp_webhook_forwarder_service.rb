class WhatsappWebhookForwarderService
  require 'net/http'
  require 'json'
  require 'uri'

  def initialize(webhook_data)
    @webhook_data = webhook_data
    @target_url = 'https://partner.ttgo.dev:5010/whatsapp-webhook'
  end

  def forward_via_http
    Thread.new do
      begin
        uri = URI(@target_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE # SSL 검증 비활성화
        http.read_timeout = 10
        http.open_timeout = 10

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'User-Agent' => 'Chatwoot-WhatsApp-Forwarder'
        })
        request.body = @webhook_data.to_json

        response = http.request(request)
        
        if response.code.to_i.between?(200, 299)
          Rails.logger.info("WhatsApp webhook data forwarded successfully via HTTP - Response: #{response.code}")
        else
          Rails.logger.warn("Failed to forward WhatsApp webhook data via HTTP: #{response.code} - #{response.message}")
        end
      rescue StandardError => e
        Rails.logger.error("Error forwarding WhatsApp webhook data via HTTP: #{e.message}")
      end
    end
  end

  def forward_via_websocket
    # WebSocket 구현 (추가 gem 필요: gem 'websocket-client-simple')
    Thread.new do
      begin
        require 'websocket-client-simple'
        
        ws_url = 'wss://partner.ttgo.dev:5010/ws'
        ws = WebSocket::Client::Simple.connect(ws_url, {
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        })

        ws.on :open do
          Rails.logger.info("WebSocket connection opened to #{ws_url}")
          ws.send(@webhook_data.to_json)
        end

        ws.on :message do |msg|
          Rails.logger.info("WebSocket message received: #{msg.data}")
          ws.close
        end

        ws.on :error do |e|
          Rails.logger.error("WebSocket error: #{e.message}")
        end

        ws.on :close do |e|
          Rails.logger.info("WebSocket connection closed")
        end

        # Keep thread alive for a short time to allow connection
        sleep(2)
      rescue LoadError
        Rails.logger.error("WebSocket gem not available. Please add 'gem \"websocket-client-simple\"' to your Gemfile")
      rescue StandardError => e
        Rails.logger.error("Error forwarding WhatsApp webhook data via WebSocket: #{e.message}")
      end
    end
  end

  def forward_via_tcp
    Thread.new do
      begin
        require 'socket'
        
        socket = TCPSocket.new('partner.ttgo.dev', 5010)
        
        # 간단한 프로토콜: 데이터 길이 + 구분자 + JSON 데이터
        
        raw_data = { type: 'whatsapp_webhook' }.merge(@webhook_data)
        json_data = raw_data.to_json

        #json_data = @webhook_data.to_json
        message = "#{json_data}"
        
        socket.write(message)
        response = socket.read
        
        Rails.logger.info("WhatsApp webhook data forwarded successfully via TCP - Response: #{response}")
        
        socket.close
      rescue StandardError => e
        Rails.logger.error("Error forwarding WhatsApp webhook data via TCP: #{e.message}")
      end
    end
  end
end
