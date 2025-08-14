class Api::V1::ProfilesController < Api::BaseController
  before_action :set_user

  def show; end

  def update
    Rails.logger.info "ProfilesController#update: profile_params = #{profile_params}"
    Rails.logger.info "ProfilesController#update: preferred_language param = #{profile_params[:preferred_language]}"
    Rails.logger.info "ProfilesController#update: auto_translate param = #{profile_params[:auto_translate]}"
    Rails.logger.info "ProfilesController#update: Raw params = #{params[:profile]}"

    if password_params[:password].present?
      render_could_not_create_error('Invalid current password') and return unless @user.valid_password?(password_params[:current_password])

      @user.update!(password_params.except(:current_password))
    end

    @user.assign_attributes(profile_params.except(:preferred_language, :auto_translate))

    # Handle preferred_language separately
    if profile_params[:preferred_language].present?
      Rails.logger.info "ProfilesController#update: Setting preferred_language to #{profile_params[:preferred_language]}"
      @user.preferred_language = profile_params[:preferred_language]
      Rails.logger.info "ProfilesController#update: After setting, preferred_language = #{@user.preferred_language}"
    end

    # Handle auto_translate separately (supporting both camelCase and snake_case)
    auto_translate_value = profile_params[:auto_translate] || profile_params[:autoTranslate]
    if auto_translate_value.present?
      Rails.logger.info "ProfilesController#update: Setting auto_translate to #{auto_translate_value}"
      @user.auto_translate = auto_translate_value
      Rails.logger.info "ProfilesController#update: After setting, auto_translate = #{@user.auto_translate}"
    end

    @user.custom_attributes.merge!(custom_attributes_params)
    Rails.logger.info 'ProfilesController#update: About to save user'
    @user.save!
    Rails.logger.info "ProfilesController#update: User saved successfully, preferred_language = #{@user.preferred_language}, auto_translate = #{@user.auto_translate}"
  end

  def avatar
    @user.avatar.attachment.destroy! if @user.avatar.attached?
    @user.reload
  end

  def auto_offline
    @user.account_users.find_by!(account_id: auto_offline_params[:account_id]).update!(auto_offline: auto_offline_params[:auto_offline] || false)
  end

  def availability
    @user.account_users.find_by!(account_id: availability_params[:account_id]).update!(availability: availability_params[:availability])
  end

  def set_active_account
    @user.account_users.find_by(account_id: profile_params[:account_id]).update(active_at: Time.now.utc)
    head :ok
  end

  def resend_confirmation
    @user.send_confirmation_instructions unless @user.confirmed?
    head :ok
  end

  def reset_access_token
    @user.access_token.regenerate_token
    @user.reload
  end

  private

  def set_user
    @user = current_user
  end

  def availability_params
    params.require(:profile).permit(:account_id, :availability)
  end

  def auto_offline_params
    params.require(:profile).permit(:account_id, :auto_offline)
  end

  def profile_params
    params.require(:profile).permit(
      :email,
      :name,
      :display_name,
      :avatar,
      :message_signature,
      :account_id,
      :preferred_language,
      :auto_translate,
      :autoTranslate,
      ui_settings: {}
    )
  end

  def custom_attributes_params
    params.require(:profile).permit(:phone_number)
  end

  def password_params
    params.require(:profile).permit(
      :current_password,
      :password,
      :password_confirmation
    )
  end
end
