class Messages::AutoTranslateJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    Rails.logger.info "Messages::AutoTranslateJob: Starting auto-translation for message ID #{message_id}"

    # Inbox에서 source_language 가져오기
    source_language = message.conversation.inbox.source_language
    realtime_providers = %w[google meta]

    # 해당 conversation에 접근 가능한 모든 agents 가져오기
    assignable_agents = message.conversation.inbox.inbox_members.includes(:user).map(&:user)

    Rails.logger.info "Messages::AutoTranslateJob: Found #{assignable_agents.count} assignable agents for inbox #{message.conversation.inbox.name}"

    # 각 agent의 선호 언어별로 번역
    target_languages = assignable_agents.map(&:preferred_language).uniq

    Rails.logger.info "Messages::AutoTranslateJob: Target languages: #{target_languages.join(', ')}"

    target_languages.each do |target_language|
      # 원본 언어와 타겟 언어가 같은 경우 스킵
      next if source_language == target_language

      realtime_providers.each do |provider|
        # 이미 해당 제공업체와 언어로 번역된 경우 스킵 (camelCase 형식 사용)
        provider_translation = message.content_attributes&.dig('realtimeTranslations', provider)
        existing_translation = if provider_translation.is_a?(Hash)
                                 provider_translation['content'].present? &&
                                   provider_translation['target_language'] == target_language
                               else
                                 false
                               end

        if existing_translation
          Rails.logger.debug { "Messages::AutoTranslateJob: Translation already exists for #{provider} to #{target_language}, skipping" }
          next
        end

        # 자동 번역 실행
        result = Messages::TranslationService.new(
          message: message,
          target_language: target_language,
          provider: provider,
          source_language: source_language,
          is_manual: false
        ).perform

        if result[:success]
          Rails.logger.info "Messages::AutoTranslateJob: Successfully translated message #{message_id} with #{provider} to #{target_language}"
        else
          Rails.logger.warn "Messages::AutoTranslateJob: Failed to translate message #{message_id} with #{provider} to #{target_language}: #{result[:error]}"
        end

      rescue StandardError => e
        Rails.logger.error "Messages::AutoTranslateJob: Error translating with #{provider} to #{target_language}: #{e.message}"
        next
      end
    end

    Rails.logger.info "Messages::AutoTranslateJob: Completed auto-translation for message ID #{message_id}"
  end
end
