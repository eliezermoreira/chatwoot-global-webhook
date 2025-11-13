class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  # NOVA AÇÃO: Webhook Global
  def process_payload_global
    phone_number_id = extract_phone_number_id
    
    if phone_number_id.blank?
      Rails.logger.error("[WHATSAPP GLOBAL] phone_number_id not found in payload")
      head :bad_request
      return
    end

    if inactive_whatsapp_number_by_id?(phone_number_id)
      Rails.logger.warn("[WHATSAPP GLOBAL] Rejected webhook for inactive phone_number_id: #{phone_number_id}")
      render json: { error: 'Inactive WhatsApp number' }, status: :unprocessable_entity
      return
    end

    # Adicionar phone_number_id aos params
    modified_params = params.to_unsafe_hash.merge(phone_number_id: phone_number_id)
    
    Webhooks::WhatsappEventsJob.perform_later(modified_params)
    head :ok
  end

  # AÇÃO ORIGINAL: Mantém compatibilidade + EXTRAI phone_number_id
  def process_payload
    if inactive_whatsapp_number?
      Rails.logger.warn("Rejected webhook for inactive WhatsApp number: #{params[:phone_number]}")
      render json: { error: 'Inactive WhatsApp number' }, status: :unprocessable_entity
      return
    end

    # Extrair phone_number_id e adicionar aos params
    phone_number_id = extract_phone_number_id
    if phone_number_id.present?
      Rails.logger.info "[WHATSAPP] Extracted phone_number_id from old route: #{phone_number_id}"
      modified_params = params.to_unsafe_hash.merge(phone_number_id: phone_number_id)
      Webhooks::WhatsappEventsJob.perform_later(modified_params)
    else
      # Fallback: usar lógica original
      Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    end
    
    head :ok
  end

  private

  # Extrair phone_number_id do payload do Meta
  def extract_phone_number_id
    params.dig(:entry, 0, :changes, 0, :value, :metadata, :phone_number_id)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP GLOBAL] Failed to extract phone_number_id: #{e.message}")
    nil
  end

  # Verificar se número está inativo (via phone_number_id)
  def inactive_whatsapp_number_by_id?(phone_number_id)
    return false if phone_number_id.blank?

    channel = Channel::Whatsapp.find_by_phone_number_id(phone_number_id)
    return false if channel.blank?

    phone_number = channel.phone_number
    inactive_numbers = GlobalConfig.get_value('INACTIVE_WHATSAPP_NUMBERS').to_s
    return false if inactive_numbers.blank?

    inactive_numbers_array = inactive_numbers.split(',').map(&:strip)
    inactive_numbers_array.include?(phone_number)
  end

  # Método de validação do token (CORRIGIDO)
  def valid_token?(token)
    # Para webhook global (phone_number == 'global')
    if params[:phone_number] == 'global'
      global_token = ENV.fetch('WHATSAPP_GLOBAL_VERIFY_TOKEN', 'whatsapp_verify_f8e7d6c5b4a39281e0f7d6c5b4a39281')
      Rails.logger.info "[WHATSAPP GLOBAL] Validating token. Received: #{token[0..20]}..., Expected: #{global_token[0..20]}..."
      return token == global_token
    end

    # Para webhook por número (lógica original)
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end

  def inactive_whatsapp_number?
    phone_number = params[:phone_number]
    return false if phone_number.blank?

    inactive_numbers = GlobalConfig.get_value('INACTIVE_WHATSAPP_NUMBERS').to_s
    return false if inactive_numbers.blank?

    inactive_numbers_array = inactive_numbers.split(',').map(&:strip)
    inactive_numbers_array.include?(phone_number)
  end
end
