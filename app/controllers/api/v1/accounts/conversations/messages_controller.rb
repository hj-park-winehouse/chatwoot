class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_api_inbox, only: :update

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  def destroy
    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    service = Messages::StatusUpdateService.new(message, 'sent')
    service.perform
    message.update!(content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    Rails.logger.info "MessagesController#translate: Starting translation for message ID #{message.id}"
    Rails.logger.debug do
      "MessagesController#translate: Target language: #{permitted_params[:target_language]}, Provider: #{permitted_params[:provider] || 'google'}"
    end

    if already_translated_content_available?
      Rails.logger.info 'MessagesController#translate: Translation already available, returning cached result'

      # 수동 번역은 언어별로 저장됨 (기존 방식)
      cached_translation = message.translations[permitted_params[:target_language]]

      return render json: {
        original_content: message.content,
        translated_content: cached_translation,
        target_language: permitted_params[:target_language],
        provider: 'cached'
      }
    end

    # Inbox에서 source_language 가져오기 (자동 번역과 동일한 방식)
    source_language = message.conversation.inbox.source_language || 'auto'

    translation_service = Messages::TranslationService.new(
      message: message,
      target_language: permitted_params[:target_language],
      provider: permitted_params[:provider] || 'google',
      source_language: source_language,
      is_manual: true
    )

    Rails.logger.debug 'MessagesController#translate: Calling translation service'
    result = translation_service.perform

    if result[:success]
      Rails.logger.info 'MessagesController#translate: Translation successful'

      # 메시지가 변경되었음을 클라이언트에 알림
      message.reload
      Rails.logger.debug 'MessagesController#translate: Broadcasting message update'

      render json: {
        original_content: message.content,
        translated_content: result[:translated_content],
        target_language: permitted_params[:target_language],
        provider: result[:provider]
      }
    else
      Rails.logger.error "MessagesController#translate: Translation failed - #{result[:error]}"
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "MessagesController#translate: Unexpected error - #{e.message}"
    Rails.logger.error "MessagesController#translate: Backtrace: #{e.backtrace.first(3).join(', ')}"
    render json: { error: 'Translation service unavailable' }, status: :internal_server_error
  end

  private

  def legacy_translate_method
    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  end

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language, :provider, :status, :external_error)
  end

  def already_translated_content_available?
    # 수동 번역은 기존 방식으로만 확인 (언어별 번역)
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end
