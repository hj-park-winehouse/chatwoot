class OpenaiGptTranslateService
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
    log_translation_start('OpenaiGptTranslateService', source_language, target_language, text)

    if text.blank?
      log_translation_warning('OpenaiGptTranslateService', 'Empty text provided')
      return nil
    end

    if api_key.blank?
      log_translation_failure('OpenaiGptTranslateService', 'OpenAI API key not configured')
      return nil
    end

    start_time = Time.current
    response = make_request
    result = parse_response(response)
    duration = Time.current - start_time

    if result
      log_translation_success('OpenaiGptTranslateService', result, duration)
    else
      log_translation_warning('OpenaiGptTranslateService', 'Translation returned empty result')
    end

    result
  rescue StandardError => e
    log_translation_failure('OpenaiGptTranslateService', e.message)
    Rails.logger.error "OpenaiGptTranslateService: Backtrace: #{e.backtrace.first(5).join(', ')}"
    nil
  end

  private

  def api_key
    key = ENV['OPENAI_API_KEY'] || Rails.application.credentials.dig(:openai, :api_key)

    # 개발 환경에서는 localhost:4000을 사용하므로 더미 키 허용
    if (Rails.env.development? || Rails.env.test?) && (key.blank? || key.in?(%w[your_openai_api_key_here your_actual_openai_key_here]))
      return 'development_key'
    end

    # placeholder 값들을 제외
    invalid_keys = ['your_openai_api_key_here', 'your_actual_openai_key_here', '', nil]

    if invalid_keys.include?(key)
      Rails.logger.warn "OpenaiGptTranslateService: Invalid API key detected: '#{key}'"
      return nil
    end

    key
  end

  def make_request
    # uri = URI('https://api.openai.com/v1/chat/completions')
    uri = URI('http://localhost:4000/v2/translate') # 개발 환경에서 로컬 더미 API 사용
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false # 로컬 HTTP 서버이므로 SSL 비활성화
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = request_body.to_json

    Rails.logger.info '🧠 OpenaiGptTranslateService: Sending HTTP request to localhost:4000'
    Rails.logger.debug { 'OpenaiGptTranslateService: Making request to dummy API' }
    Rails.logger.debug { "OpenaiGptTranslateService: Request body: #{request_body}" }

    start_time = Time.current
    response = http.request(request)
    duration = Time.current - start_time

    Rails.logger.info "📡 OpenaiGptTranslateService: HTTP response received in #{duration.round(3)}s"
    Rails.logger.debug { "OpenaiGptTranslateService: Response status: #{response.code}" }
    Rails.logger.debug { "OpenaiGptTranslateService: Response body: #{response.body.truncate(200)}" }

    response
  end

  def request_body
    {
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: system_prompt
        },
        {
          role: 'user',
          content: "Translate this text to #{target_language_name}: #{text}"
        }
      ],
      max_tokens: 2000,
      temperature: 0.1
    }
  end

  def system_prompt
    'You are a professional translator. Translate the given text accurately to the target language. ' \
      'Maintain the original tone, context, and meaning. ' \
      'Only return the translated text without any additional explanation or formatting.'
  end

  def target_language_name
    language_mapping = {
      'ko' => 'Korean',
      'en' => 'English',
      'ja' => 'Japanese',
      'zh' => 'Chinese',
      'es' => 'Spanish',
      'fr' => 'French',
      'de' => 'German',
      'it' => 'Italian',
      'pt' => 'Portuguese',
      'ru' => 'Russian',
      'ar' => 'Arabic',
      'hi' => 'Hindi',
      'th' => 'Thai',
      'vi' => 'Vietnamese'
    }

    language_mapping[target_language] || target_language
  end

  def parse_response(response)
    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    content = body.dig('choices', 0, 'message', 'content')

    if content.present?
      # 앞뒤 공백 및 따옴표 제거
      content.strip.gsub(/^["']|["']$/, '')
    else
      Rails.logger.warn "OpenaiGptTranslateService: No content in response: #{body}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "OpenaiGptTranslateService: JSON parsing error: #{e.message}"
    Rails.logger.error "OpenaiGptTranslateService: Response body: #{response.body}"
    nil
  rescue StandardError => e
    Rails.logger.error "OpenaiGptTranslateService: Error parsing response: #{e.message}"
    nil
  end
end
