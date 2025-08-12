class GoogleTranslateService
  require 'net/http'
  require 'json'
  include TranslationLogger

  attr_reader :text, :target_language, :source_language

  def initialize(text, target_language, source_language = 'auto')
    @text = text
    @target_language = target_language
    @source_language = source_language
  end

  def translate
    log_translation_start('GoogleTranslateService', source_language, target_language, text)

    if text.blank?
      log_translation_warning('GoogleTranslateService', 'Empty text provided')
      return nil
    end

    if api_key.blank?
      log_translation_failure('GoogleTranslateService', 'API key not configured')
      return nil
    end

    start_time = Time.current
    response = make_request
    result = parse_response(response)
    duration = Time.current - start_time

    if result
      log_translation_success('GoogleTranslateService', result, duration)
    else
      log_translation_warning('GoogleTranslateService', 'Translation returned empty result')
    end

    result
  rescue StandardError => e
    log_translation_failure('GoogleTranslateService', e.message)
    Rails.logger.error "GoogleTranslateService: Backtrace: #{e.backtrace.first(5).join(', ')}"
    nil
  end

  private

  def api_key
    key = ENV['GOOGLE_TRANSLATE_API_KEY'] || Rails.application.credentials.dig(:google, :translate_api_key)

    # 개발 환경에서는 localhost:4000을 사용하므로 더미 키 허용
    if (Rails.env.development? || Rails.env.test?) && (key.blank? || key.in?(%w[your_google_translate_api_key_here
                                                                                your_actual_google_api_key_here]))
      return 'development_key'
    end

    # placeholder 값들을 제외
    invalid_keys = ['your_google_translate_api_key_here', 'your_actual_google_api_key_here', '', nil]

    if invalid_keys.include?(key)
      Rails.logger.warn "GoogleTranslateService: Invalid API key detected: '#{key}'"
      return nil
    end

    key
  end

  def make_request
    # uri = URI('https://translation.googleapis.com/language/translate/v2')
    uri = URI('http://localhost:4000/v2/translate')

    # JSON body로 요청 데이터 구성
    request_body = {
      key: api_key,
      q: text,
      source: source_language,
      target: target_language,
      format: 'text'
    }.to_json

    Rails.logger.debug { "GoogleTranslateService: Request URL: #{uri}" }
    Rails.logger.debug { "GoogleTranslateService: Request body: #{request_body}" }
    Rails.logger.info '🌐 GoogleTranslateService: Sending HTTP request to localhost:4000'

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = request_body

    Rails.logger.debug 'GoogleTranslateService: Sending HTTP request'
    start_time = Time.current
    response = http.request(request)
    duration = Time.current - start_time

    Rails.logger.info "📡 GoogleTranslateService: HTTP response received in #{duration.round(3)}s"
    Rails.logger.debug { "GoogleTranslateService: Response code: #{response.code}" }
    Rails.logger.debug { "GoogleTranslateService: Response body: #{response.body.truncate(200)}" }

    unless response.code == '200'
      Rails.logger.error "GoogleTranslateService: HTTP Error #{response.code}: #{response.body}"
      raise "HTTP Error: #{response.code}"
    end

    response
  end

  def parse_response(response)
    Rails.logger.debug 'GoogleTranslateService: Parsing response body'

    begin
      data = JSON.parse(response.body)
      Rails.logger.debug 'GoogleTranslateService: Response parsed successfully'
    rescue JSON::ParserError => e
      Rails.logger.error "GoogleTranslateService: JSON parse error: #{e.message}"
      Rails.logger.error "GoogleTranslateService: Response body: #{response.body}"
      return nil
    end

    translations = data.dig('data', 'translations')

    if translations.blank?
      Rails.logger.warn 'GoogleTranslateService: No translations found in response'
      Rails.logger.debug { "GoogleTranslateService: Response data: #{data}" }
      return nil
    end

    translated_text = translations.first&.dig('translatedText')

    if translated_text.blank?
      Rails.logger.warn 'GoogleTranslateService: Empty translated text in response'
    else
      Rails.logger.debug 'GoogleTranslateService: Successfully extracted translated text'
    end

    translated_text
  end
end
