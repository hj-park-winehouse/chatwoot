class Messages::ManualTranslateJob < ApplicationJob
  queue_as :default

  def perform(message_id, provider, target_language = 'ko')
    message = Message.find_by(id: message_id)
    return { success: false, error: 'Message not found' } unless message

    Rails.logger.info "Messages::ManualTranslateJob: Starting manual translation for message ID #{message_id} with #{provider}"
    Rails.logger.debug { "Messages::ManualTranslateJob: Target language: #{target_language}" }

    # 이미 해당 제공업체로 번역된 경우 캐시된 결과 반환
    existing_translation = message.content_attributes&.dig('translations', provider)
    if existing_translation.present?
      Rails.logger.debug { "Messages::ManualTranslateJob: Translation already exists for provider #{provider}, returning cached result" }
      return {
        success: true,
        translated_content: existing_translation,
        provider: 'cached',
        target_language: target_language
      }
    end

    # 번역 실행
    result = Messages::TranslationService.new(
      message: message,
      target_language: target_language,
      provider: provider
    ).perform

    if result[:success]
      Rails.logger.info "Messages::ManualTranslateJob: Successfully translated message #{message_id} with #{provider}"
    else
      Rails.logger.warn "Messages::ManualTranslateJob: Failed to translate message #{message_id} with #{provider}: #{result[:error]}"
    end

    result
  rescue StandardError => e
    error_msg = "Messages::ManualTranslateJob: Error translating with #{provider}: #{e.message}"
    Rails.logger.error error_msg
    Rails.logger.error "Messages::ManualTranslateJob: Backtrace: #{e.backtrace.first(3).join(', ')}"
    { success: false, error: error_msg }
  end
end
