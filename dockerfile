FROM chatwoot/chatwoot:v4.7.0-ce

COPY app/controllers/webhooks/whatsapp_controller.rb /app/app/controllers/webhooks/whatsapp_controller.rb
COPY app/jobs/webhooks/whatsapp_events_job.rb /app/app/jobs/webhooks/whatsapp_events_job.rb
COPY app/models/channel/whatsapp.rb /app/app/models/channel/whatsapp.rb
COPY config/routes.rb /app/config/routes.rb

ENV WHATSAPP_GLOBAL_VERIFY_TOKEN=whatsapp_verify_f8e7d6c5b4a39281e0f7d6c5b4a39281
