class MetaTranslateService
  require 'net/http'
  require 'json'

  attr_reader :text, :target_language, :source_language

  def initialize(text, target_language, source_language = 'auto')
    @text = text
    @target_language = target_language
    @source_language = source_language
  end

  def translate
    Rails.logger.info "MetaTranslateService: Starting translation from '#{source_language}' to '#{target_language}'"
    Rails.logger.debug { "MetaTranslateService: Text to translate: #{text.truncate(100)}" }

    if text.blank?
      Rails.logger.warn 'MetaTranslateService: Empty text provided for translation'
      return nil
    end

    if access_token.blank?
      Rails.logger.error 'MetaTranslateService: Access token not configured'
      return nil
    end

    Rails.logger.debug 'MetaTranslateService: Making API request to Meta Translate'
    response = make_request
    result = parse_response(response)

    if result
      Rails.logger.info 'MetaTranslateService: Translation successful'
      Rails.logger.debug { "MetaTranslateService: Translated text: #{result.truncate(100)}" }
    else
      Rails.logger.warn 'MetaTranslateService: Translation returned empty result'
    end

    result
  rescue StandardError => e
    Rails.logger.error "MetaTranslateService: Translation failed - #{e.message}"
    Rails.logger.error "MetaTranslateService: Backtrace: #{e.backtrace.first(5).join(', ')}"
    nil
  end

  private

  def access_token
    token = ENV['META_TRANSLATE_ACCESS_TOKEN'] || Rails.application.credentials.dig(:meta, :translate_access_token)

    # 개발 환경에서는 localhost:4000을 사용하므로 더미 토큰 허용
    if (Rails.env.development? || Rails.env.test?) && (token.blank? || token.in?(%w[your_meta_translate_access_token_here
                                                                                    your_actual_meta_token_here]))
      return 'development_token'
    end

    # placeholder 값들을 제외
    invalid_tokens = ['your_meta_translate_access_token_here', 'your_actual_meta_token_here', '', nil]

    if invalid_tokens.include?(token)
      Rails.logger.warn "MetaTranslateService: Invalid access token detected: '#{token}'"
      return nil
    end

    token
  end

  def make_request
    # uri = URI('https://api.metatext.ai/translate')
    uri = URI('http://localhost:4000/v2/translate')

    Rails.logger.debug { "MetaTranslateService: Request URL: #{uri}" }
    Rails.logger.debug { "MetaTranslateService: Request parameters: source=#{source_language}, target=#{target_language}" }
    Rails.logger.info '🤖 MetaTranslateService: Sending HTTP request to localhost:4000'

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'

    request_body = {
      text: text,
      source_language: source_language,
      target_language: target_language
    }

    request.body = request_body.to_json

    Rails.logger.debug { "MetaTranslateService: Request body: #{request_body}" }

    start_time = Time.current
    response = http.request(request)
    duration = Time.current - start_time

    Rails.logger.info "📡 MetaTranslateService: HTTP response received in #{duration.round(3)}s"
    Rails.logger.debug { "MetaTranslateService: Response code: #{response.code}" }
    Rails.logger.debug { "MetaTranslateService: Response body: #{response.body.truncate(200)}" }
    Rails.logger.debug { "MetaTranslateService: Request body: #{request_body}" }

    Rails.logger.debug 'MetaTranslateService: Sending HTTP request'
    start_time = Time.current
    response = http.request(request)
    duration = Time.current - start_time

    Rails.logger.debug { "MetaTranslateService: Response received in #{duration.round(3)}s" }
    Rails.logger.debug { "MetaTranslateService: Response code: #{response.code}" }

    unless response.code == '200'
      Rails.logger.error "MetaTranslateService: HTTP Error #{response.code}: #{response.body}"
      raise "HTTP Error: #{response.code}"
    end

    response
  end

  def parse_response(response)
    Rails.logger.debug 'MetaTranslateService: Parsing response body'

    begin
      data = JSON.parse(response.body)
      Rails.logger.debug 'MetaTranslateService: Response parsed successfully'
    rescue JSON::ParserError => e
      Rails.logger.error "MetaTranslateService: JSON parse error: #{e.message}"
      Rails.logger.error "MetaTranslateService: Response body: #{response.body}"
      return nil
    end

    translated_text = data.dig('translation', 'text')

    if translated_text.blank?
      Rails.logger.warn 'MetaTranslateService: No translation found in response'
      Rails.logger.debug { "MetaTranslateService: Response data: #{data}" }
    else
      Rails.logger.debug 'MetaTranslateService: Successfully extracted translated text'
    end

    translated_text
  end
end
