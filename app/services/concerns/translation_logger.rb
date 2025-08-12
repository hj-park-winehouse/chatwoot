module TranslationLogger
  extend ActiveSupport::Concern

  private

  def log_translation_start(service_name, source_lang, target_lang, text_preview)
    Rails.logger.info "🌐 #{service_name}: Starting translation"
    Rails.logger.info "   📝 From: #{source_lang} → To: #{target_lang}"
    Rails.logger.info "   📄 Text: #{text_preview.truncate(100)}"
  end

  def log_translation_success(service_name, result_preview, duration = nil)
    duration_text = duration ? " (#{duration.round(3)}s)" : ''
    Rails.logger.info "✅ #{service_name}: Translation successful#{duration_text}"
    Rails.logger.info "   📝 Result: #{result_preview.truncate(100)}"
  end

  def log_translation_failure(service_name, error_message)
    Rails.logger.error "❌ #{service_name}: Translation failed"
    Rails.logger.error "   🔥 Error: #{error_message}"
  end

  def log_translation_warning(service_name, warning_message)
    Rails.logger.warn "⚠️  #{service_name}: #{warning_message}"
  end

  def log_api_request(service_name, url, params = {})
    Rails.logger.debug { "🌐 #{service_name}: Making API request" }
    Rails.logger.debug { "   🔗 URL: #{url}" }
    Rails.logger.debug { "   📋 Params: #{params}" } if params.any?
  end

  def log_api_response(service_name, status_code, duration)
    status_emoji = status_code == '200' ? '✅' : '❌'
    Rails.logger.debug { "#{status_emoji} #{service_name}: API response #{status_code} (#{duration.round(3)}s)" }
  end

  def log_database_operation(operation, details)
    Rails.logger.debug { "💾 Database #{operation}: #{details}" }
  end
end
