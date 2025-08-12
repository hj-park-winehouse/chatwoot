class Messages::TranslationService
  include TranslationLogger

  attr_reader :message, :target_language, :provider, :source_language, :is_manual

  def initialize(message:, target_language:, provider: 'google', source_language: 'auto', is_manual: false)
    @message = message
    @target_language = target_language
    @source_language = source_language
    @provider = provider
    @is_manual = is_manual
  end

  def perform
    Rails.logger.info "Messages::TranslationService: Starting translation for message ID #{message.id}"
    Rails.logger.debug { "Messages::TranslationService: Provider: #{provider}, Target language: #{target_language}" }
    Rails.logger.debug { "Messages::TranslationService: Message content: #{content.truncate(100)}" }

    return { success: false, error: 'Message content is empty' } if content.blank?

    if already_translated?
      Rails.logger.info "Messages::TranslationService: Translation already exists for provider #{provider}"

      # 자동 번역 vs 수동 번역 구분
      is_realtime_provider = !is_manual && %w[google meta].include?(provider.downcase)

      if is_realtime_provider
        # 자동 번역: realtimeTranslations에서 가져오기 (프로바이더별, camelCase)
        provider_translation = message.content_attributes&.dig('realtimeTranslations', provider)
        existing_translation = provider_translation.is_a?(Hash) ? provider_translation['content'] : nil
      else
        # 수동 번역: translations에서 가져오기 (기존 방식)
        existing_translation = message.content_attributes&.dig('translations', target_language)
      end

      return {
        success: true,
        translated_content: existing_translation,
        target_language: target_language,
        provider: 'cached'
      }
    end

    Rails.logger.debug { "Messages::TranslationService: Attempting translation with #{provider} provider" }
    translated_content = translate_content

    if translated_content.present?
      Rails.logger.info 'Messages::TranslationService: Translation successful, saving to database'
      save_translation(translated_content)
      {
        success: true,
        translated_content: translated_content,
        target_language: target_language,
        provider: provider
      }
    else
      error_msg = 'Translation failed with all available providers'
      Rails.logger.error "Messages::TranslationService: #{error_msg}"
      { success: false, error: error_msg }
    end
  rescue StandardError => e
    error_msg = "Translation service error: #{e.message}"
    Rails.logger.error "Messages::TranslationService: #{error_msg}"
    Rails.logger.error "Messages::TranslationService: Backtrace: #{e.backtrace.first(5).join(', ')}"
    { success: false, error: error_msg }
  end

  private

  def content
    @content ||= extract_content_for_translation
  end

  def already_translated?
    # 자동 번역 vs 수동 번역 구분
    is_realtime_provider = !is_manual && %w[google meta].include?(provider.downcase)

    if is_realtime_provider
      # 자동 번역: realtimeTranslations에서 확인 (프로바이더별, camelCase)
      realtime_translations = message.content_attributes&.dig('realtimeTranslations') || {}
      provider_translation = realtime_translations[provider]

      result = if provider_translation.is_a?(Hash)
                 provider_translation['content'].present? && provider_translation['target_language'] == target_language
               else
                 false
               end
    else
      # 수동 번역: translations에서 확인 (기존 방식)
      translations = message.content_attributes&.dig('translations') || {}
      result = translations[target_language].present?
    end

    Rails.logger.debug 'Messages::TranslationService: Checking existing translations'
    Rails.logger.debug { "Messages::TranslationService: Provider '#{provider}' for language '#{target_language}' exists: #{result}" }

    result
  end

  def extract_content_for_translation
    if message.content_type == 'incoming_email'
      # 이메일의 경우 HTML 또는 텍스트 콘텐츠 추출
      email_content = message.content_attributes&.dig('email')
      return email_content&.dig('htmlContent', 'full') || email_content&.dig('textContent', 'full') || message.content
    end

    message.content
  end

  def translate_content
    Rails.logger.info "🔄 Messages::TranslationService: Starting translation with '#{provider}' provider"
    Rails.logger.debug { "📊 Translation mode: #{is_manual ? 'Manual' : 'Automatic'}" }
    Rails.logger.debug { "📝 Content length: #{content.length} characters" }

    result = case provider.downcase
             when 'google'
               Rails.logger.debug '🌐 Attempting Google translation...'
               translate_with_google
             when 'meta'
               Rails.logger.debug '🤖 Attempting Meta translation...'
               translate_with_meta
             when 'openai', 'gpt'
               Rails.logger.debug '🧠 Attempting OpenAI GPT translation...'
               translate_with_openai_gpt
             when 'mock'
               Rails.logger.debug '🎭 Using Mock translation for testing...'
               translate_with_mock
             else
               Rails.logger.warn "❓ Messages::TranslationService: Unknown provider '#{provider}', defaulting to Google"
               translate_with_google
             end

    # 번역 실패시 "unknown" 메시지 반환
    if result.nil?
      Rails.logger.warn "⚠️  Messages::TranslationService: #{provider} translation failed, returning 'unknown' message"
      result = 'unknown'
    end

    result
  end

  def translate_with_google
    Rails.logger.info '🌐 Messages::TranslationService: Starting Google translation'
    Rails.logger.debug { "📝 Content: #{content.truncate(100)}" }
    Rails.logger.debug { "🌍 From: #{source_language} → To: #{target_language}" }

    start_time = Time.current
    result = GoogleTranslateService.new(content, target_language, source_language).translate
    duration = Time.current - start_time

    if result.present?
      Rails.logger.info "✅ Messages::TranslationService: Google translation successful (#{duration.round(3)}s)"
      Rails.logger.debug { "📝 Result: #{result.truncate(100)}" }
    else
      Rails.logger.error '❌ Messages::TranslationService: Google translation returned empty result'
    end

    result
  rescue StandardError => e
    Rails.logger.error "💥 Messages::TranslationService: GoogleTranslateService error: #{e.message}"
    Rails.logger.error "🔍 Backtrace: #{e.backtrace.first(3).join(', ')}"
    nil
  end

  def translate_with_meta
    Rails.logger.info '🤖 Messages::TranslationService: Starting Meta translation'
    Rails.logger.debug { "📝 Content: #{content.truncate(100)}" }
    Rails.logger.debug { "🌍 From: #{source_language} → To: #{target_language}" }

    start_time = Time.current
    result = MetaTranslateService.new(content, target_language, source_language).translate
    duration = Time.current - start_time

    if result.present?
      Rails.logger.info "✅ Messages::TranslationService: Meta translation successful (#{duration.round(3)}s)"
      Rails.logger.debug { "📝 Result: #{result.truncate(100)}" }
    else
      Rails.logger.error '❌ Messages::TranslationService: Meta translation returned empty result'
    end

    result
  rescue StandardError => e
    Rails.logger.error "💥 Messages::TranslationService: MetaTranslateService error: #{e.message}"
    Rails.logger.error "🔍 Backtrace: #{e.backtrace.first(3).join(', ')}"
    nil
  end

  def translate_with_openai_gpt
    Rails.logger.info '🧠 Messages::TranslationService: Starting OpenAI GPT translation'
    Rails.logger.debug { "📝 Content: #{content.truncate(100)}" }
    Rails.logger.debug { "🌍 From: #{source_language} → To: #{target_language}" }

    start_time = Time.current
    result = OpenaiGptTranslateService.new(content, target_language, source_language).translate
    duration = Time.current - start_time

    if result.present?
      Rails.logger.info "✅ Messages::TranslationService: OpenAI GPT translation successful (#{duration.round(3)}s)"
      Rails.logger.debug { "📝 Result: #{result.truncate(100)}" }
    else
      Rails.logger.error '❌ Messages::TranslationService: OpenAI GPT translation returned empty result'
    end

    result
  rescue StandardError => e
    Rails.logger.error "💥 Messages::TranslationService: OpenaiGptTranslateService error: #{e.message}"
    Rails.logger.error "🔍 Backtrace: #{e.backtrace.first(3).join(', ')}"
    nil
  end

  def translate_with_mock
    Rails.logger.debug 'Messages::TranslationService: Using MockTranslateService'
    MockTranslateService.new(content, target_language, source_language).translate
  rescue StandardError => e
    Rails.logger.error "Messages::TranslationService: MockTranslateService error: #{e.message}"
    nil
  end

  def save_translation(translated_content)
    Rails.logger.debug 'Messages::TranslationService: Saving translation to database'

    # content_attributes에서 translations 가져오기
    current_content_attributes = message.content_attributes&.dup || {}

    # 자동 번역 vs 수동 번역 구분
    is_realtime_provider = !is_manual && %w[google meta].include?(provider.downcase)

    if is_realtime_provider
      # 자동 번역: realtimeTranslations에 프로바이더별로 저장 (프론트엔드 구조에 맞춤, camelCase)
      current_realtime_translations = current_content_attributes['realtimeTranslations'] || {}

      current_realtime_translations[provider] = {
        'content' => translated_content,
        'target_language' => target_language,
        'source_language' => source_language,
        'provider' => provider,
        'translated_at' => Time.current.iso8601
      }

      current_content_attributes['realtimeTranslations'] = current_realtime_translations
      Rails.logger.debug do
        "Messages::TranslationService: Saved to realtimeTranslations[#{provider}]: #{current_realtime_translations[provider]}"
      end
    else
      # 수동 번역 (GPT 등): translations에 문자열로 저장 (기존 방식)
      current_translations = current_content_attributes['translations'] || {}
      current_translations[target_language] = translated_content

      current_content_attributes['translations'] = current_translations
      Rails.logger.debug { "Messages::TranslationService: Saved to translations: #{current_translations}" }
    end

    message.content_attributes = current_content_attributes
    message.content_attributes_will_change!

    message.save!

    Rails.logger.debug 'Messages::TranslationService: Message saved, Rails will handle ActionCable broadcast automatically'

    # 저장 후 확인
    Rails.logger.debug { "Messages::TranslationService: Verification - saved content_attributes: #{message.reload.content_attributes}" }
    Rails.logger.info "Messages::TranslationService: Translation saved successfully for provider '#{provider}' and language '#{target_language}'"
  rescue StandardError => e
    Rails.logger.error "Messages::TranslationService: Failed to save translation: #{e.message}"
    raise e
  end
end
