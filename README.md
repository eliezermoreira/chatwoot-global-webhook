<div align="center">

# 🌐 Chatwoot Global Webhook

**Webhook único para múltiplos números WhatsApp _(coexistência WABA)_ no Chatwoot**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Chatwoot](https://img.shields.io/badge/Chatwoot-v4.7.0--ce-blue)](https://www.chatwoot.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)

</div>

---

## 🚨 **O Problema**

O Chatwoot oficial exige **um webhook diferente para cada número WhatsApp**:
```
Cliente A - Número 1 → webhook: /whatsapp/5511912345678
Cliente A - Número 2 → webhook: /whatsapp/5511987654321
Cliente B - Número 1 → webhook: /whatsapp/5521923456789
Cliente B - Número 2 → webhook: /whatsapp/5521987651234
...
```

**Isso causa:**
- ❌ Tokens diferentes para cada número
- ❌ Avisos constantes de "reconexão necessária"

**Cenário real:** 5 clientes com 3 números cada = **15 webhooks para gerenciar manualmente**.

---

## **A Solução**

Este fork implementa **um webhook global único** que atende todos os números:
```
Cliente A - Número 1 ┐
Cliente A - Número 2 ├→ webhook: /whatsapp/global
Cliente B - Número 1 │   (um único endpoint)
Cliente B - Número 2 ┘
...
```

**Resultado:**
- ✅ Configurar webhook **uma única vez** no Meta
- ✅ Um único token global
- ✅ Zero configuração ao adicionar novos números

**Mesmo cenário:** 5 clientes com 3 números cada = **1 webhook global**.

---

## **Como Funciona**

### **Arquitetura**
```
┌──────────────────────────────────────┐
│       Meta WhatsApp Business         │
│    (Todos os números do app)         │
└──────────────────────────────────────┘
                 │
                 │ Envia todas as mensagens
                 │ para o mesmo webhook
                 ▼
┌──────────────────────────────────────┐
│  /webhooks/whatsapp/global           │
│  (Webhook Global)                    │
└──────────────────────────────────────┘
                 │
                 │ 1. Extrai phone_number_id
                 │    do payload
                 ▼
┌──────────────────────────────────────┐
│  Controller                          │
│  - Valida token global               │
│  - Adiciona phone_number_id ao job   │
└──────────────────────────────────────┘
                 │
                 │ 2. Enfileira job
                 ▼
┌──────────────────────────────────────┐
│  WhatsappEventsJob                   │
│  - Busca canal por phone_number_id   │
│  - Roteia para inbox correto         │
└──────────────────────────────────────┘
                 │
                 ▼
        ┌────────────────┐
        │ Inbox Correta  │
        └────────────────┘
```

### **O Que Muda no Código**

**4 arquivos modificados:**

1. **whatsapp_controller.rb**
   - Adiciona método `process_payload_global`
   - Extrai `phone_number_id` do payload do Meta
   - Valida token global via ENV

2. **whatsapp_events_job.rb**
   - Prioriza busca por `phone_number_id`
   - Fallback para `phone_number` (compatibilidade)

3. **whatsapp.rb (model)**
   - Adiciona método `find_by_phone_number_id`
   - Query por JSONB field no PostgreSQL

4. **routes.rb**
   - Mantém rotas antigas (compatibilidade)
   - Webhook global usa rota catch-all `/:phone_number`

### **Por Que Funciona**

O Meta WhatsApp envia no payload o `phone_number_id`:
```json
{
  "entry": [{
    "changes": [{
      "value": {
        "metadata": {
          "phone_number_id": "4719239660xxxxx"  ← Identificador único
        }
      }
    }]
  }]
}
```

O código extrai esse ID e busca o canal correspondente no banco de dados, **eliminando a necessidade de webhooks individuais**.

---

## 🚀 **Instalação**

### **Passo 1: Clone e Build**
```bash
# Clone
git clone https://github.com/eliezermoreira/chatwoot-global-webhook.git
cd chatwoot-global-webhook

# Build da imagem customizada
docker build -t chatwoot-custom:v4.7.0-global .
```

### **Passo 2: Editar docker-compose.yml**

Seu `docker-compose.yml` da stack do Chatwoot precisa de **3 mudanças**:

**1. Trocar imagem do `chatwoot_rails`:**
```yaml
services:
  chatwoot_rails:
    image: chatwoot-custom:v4.7.0-global  # ← Era: chatwoot/chatwoot:v4.7.0-ce ou outra versão
```

**2. Adicionar variável no `chatwoot_rails`:**
```yaml
  chatwoot_rails:
    environment:
      # ... outras variáveis ...
      - WHATSAPP_GLOBAL_VERIFY_TOKEN=whatsapp_verify_f8e7d6c5b4a39281e0f7d6c5b4a39281   # ← Recomendado substituir o token

**3. Fazer o mesmo no `chatwoot_sidekiq`:**
```yaml
  chatwoot_sidekiq:
    image: chatwoot-custom:v4.7.0-global  # ← Trocar imagem para a mesma do rails
    environment:
      # ... outras variáveis ...
      - WHATSAPP_GLOBAL_VERIFY_TOKEN=whatsapp_verify_f8e7d6c5b4a39281e0f7d6c5b4a39281   # ← Recomendado substituir o token
```

### **Passo 3: Deploy**
```bash
# Deploy
docker stack deploy -c docker-compose.yml chatwoot  # ← Conforme stack do seu Chatwoot

# Aguardar subir (1-2 minutos)
sleep 60

# Testar webhook
curl -X GET "https://seu-dominio.com/webhooks/whatsapp/global?hub.mode=subscribe&hub.verify_token=whatsapp_verify_f8e7d6c5b4a39281e0f7d6c5b4a39281&hub.challenge=test"   # ← Lembre-se de substituir o token

# ✅ Deve retornar: test
```

### **Passo 4: Configurar Meta Developers**

**Acessar:**
```
https://developers.facebook.com/
→ Seus Aplicativos
→ [Seu App WhatsApp]
→ WhatsApp → Configuration → Webhook
```

**Configurar:**
```
Callback URL: https://seu-dominio.com/webhooks/whatsapp/global
Verify Token: whatsapp_verify_f8e7d6c5b4a39281e0f7d6c5b4a39281   # ← Lembre-se de substituir o token

Webhook Fields:
✅ messages
✅ message_status
```

**Clicar:** "Verify and Save"

**IMPORTANTE:** Remover webhooks individuais dos números:
```
Configuration → Phone Numbers
→ Clicar em cada número
→ Webhook Settings → Remover
```

### **Passo 5: Conectar WhatsApp no Chatwoot**
```
1. Login no Chatwoot
2. Settings → Inboxes → Add Inbox
3. WhatsApp → WhatsApp Cloud
4. Preencher:
   - Phone Number ID (do Meta)
   - Business Account ID (do Meta)
   - API Key (do Meta)
5. Create WhatsApp Channel
```

### **Passo 6: Testar**

Envie uma mensagem no WhatsApp para o número conectado.

**Ver logs:**
```bash
# Webhook recebendo
docker service logs chatwoot_chatwoot_rails -f | grep "POST.*whatsapp/global"

# Job processando
docker service logs chatwoot_chatwoot_sidekiq -f | grep "WhatsappEventsJob"
```

**✅ Mensagem deve aparecer no Chatwoot!**

---

## 🔧 **Troubleshooting Rápido**

### **Webhook retorna 401**
```bash
# Verificar variável
docker exec $(docker ps -q -f "name=chatwoot_rails") env | grep WHATSAPP_GLOBAL

# Se não existir, adicionar no docker-compose.yml e redesployer
```

### **Mensagens não chegam**
```bash
# Verificar phone_number_id no banco
docker exec -it $(docker ps -q -f "name=postgres") psql -U app_user -d chatwoot_database -c "SELECT phone_number, provider_config->>'phone_number_id' FROM channel_whatsapp;"

# Reconectar caixa no Chatwoot se phone_number_id estiver NULL
```

### **Meta não valida webhook**
```bash
# Testar manualmente
curl -I https://seu-dominio.com/webhooks/whatsapp/global

# Verificar: SSL válido, domínio acessível, porta 443 aberta
```

---

## 📝 **Token Customizado (RECOMENDADO)**

Para produção, gere um token mais seguro:
```bash
# Gerar
openssl rand -hex 32

# Usar no docker-compose.yml E no Meta Developers
```

---

## 📄 **Licença**

MIT License - veja [LICENSE](LICENSE) para detalhes.

---

<div align="center">

**Desenvolvido para a comunidade Chatwoot**

Se este projeto ajudou você, considere dar uma ⭐

</div>
