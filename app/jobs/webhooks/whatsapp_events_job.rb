class Webhooks::WhatsappEventsJob < ApplicationJob
  queue_as :low

  def perform(params = {})
    channel = find_channel_from_whatsapp_business_payload(params)
    
    if channel_is_inactive?(channel)
      Rails.logger.warn("Inactive WhatsApp channel: #{channel&.phone_number || "unknown - #{params[:phone_number]}"}")
      return
    end

    case channel.provider
    when 'whatsapp_cloud'
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: channel.inbox, params: params).perform
    else
      Whatsapp::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    end
  end

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

    false
  end

  def find_channel_by_url_param(params)
    return unless params[:phone_number]

    Channel::Whatsapp.find_by(phone_number: params[:phone_number])
  end

  # NOVA FUNÇÃO: Buscar por phone_number_id direto
  def find_channel_by_phone_number_id(params)
    return unless params[:phone_number_id]

    Channel::Whatsapp.find_by_phone_number_id(params[:phone_number_id])
  end

  def find_channel_from_whatsapp_business_payload(params)
    # PRIORIDADE 1: Se phone_number_id veio nos params (webhook global)
    channel = find_channel_by_phone_number_id(params)
    return channel if channel.present?

    # PRIORIDADE 2: Se é payload do WhatsApp Business Account
    return get_channel_from_wb_payload(params) if params[:object] == 'whatsapp_business_account'

    # PRIORIDADE 3: Buscar por phone_number da URL (compatibilidade)
    find_channel_by_url_param(params)
  end

  def get_channel_from_wb_payload(wb_params)
    phone_number = "+#{wb_params[:entry].first[:changes].first.dig(:value, :metadata, :display_phone_number)}"
    phone_number_id = wb_params[:entry].first[:changes].first.dig(:value, :metadata, :phone_number_id)
    
    # Tentar buscar direto por phone_number_id (mais confiável)
    channel = Channel::Whatsapp.find_by_phone_number_id(phone_number_id)
    return channel if channel.present?

    # Fallback: buscar por phone_number e validar
    channel = Channel::Whatsapp.find_by(phone_number: phone_number)
    return channel if channel && channel.provider_config['phone_number_id'] == phone_number_id
  end
end
