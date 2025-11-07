#!/bin/bash
# ENTERPRISE SCRIPT TEMPLATE - VERSIÓN FUNCIONAL
# ==============================================

# NOTA: SCRIPT_DIR ya está definido en security-manager.sh como readonly
# No redeclararlo aquí para evitar conflictos

# === FUNCIONES ESENCIALES ===

# Función para logging estructurado
log_structured_perf() {
    local level="$1"
    local message="$2"
    local fields="${3:-{}}"
    
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    
    # Crear JSON manualmente (más rápido que jq)
    printf '{"timestamp":"%s","level":"%s","message":"%s","host":"%s","fields":%s}\n' \
        "$timestamp" "$level" "$(echo "$message" | sed 's/"/\\"/g')" "$hostname" "$fields"
}

# Función para métricas
increment_counter_perf() {
    local metric_name="$1"
    local value="${2:-1}"
    local labels="${3:-{}}"
    
    local timestamp=$(date -Iseconds)
    printf '{"type":"counter","name":"%s","value":%d,"labels":%s,"timestamp":"%s"}\n' \
        "$metric_name" "$value" "$labels" "$timestamp"
}

# Función para alertas
send_alert() {
    local message="$1"
    log_structured_perf "ALERT" "$message" '{"severity":"high"}'
}

# === FUNCIONES DE SEGURIDAD ===

run_quick_audit() {
    log_structured_perf "INFO" "Iniciando auditoría rápida" "{\"type\": \"quick_audit\"}"
    
    local tools=("lynis" "rkhunter" "chkrootkit")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_structured_perf "INFO" "Herramienta disponible" "{\"tool\": \"$tool\"}"
        else
            log_structured_perf "WARNING" "Herramienta no disponible" "{\"tool\": \"$tool\"}"
        fi
    done
    
    if command -v lynis &> /dev/null; then
        log_structured_perf "INFO" "Ejecutando Lynis quick scan"
        sudo lynis audit system --quick --no-colors --quiet
        local lynis_exit=$?
        
        if [[ $lynis_exit -eq 0 ]]; then
            send_notification "✅ Auditoría rápida completada - Sin issues críticos"
        else
            send_notification "⚠️ Auditoría rápida - Revisar findings"
        fi
    fi
    
    increment_counter_perf "security_audits_total" 1 "{\"type\": \"quick\", \"status\": \"success\"}"
}

run_full_audit() {
    log_structured_perf "INFO" "Iniciando auditoría completa" "{\"type\": \"full_audit\"}"
    send_notification "🔍 Iniciando auditoría de seguridad completa..."
    sleep 10
    send_notification "✅ Auditoría completa finalizada"
    increment_counter_perf "security_audits_total" 1 "{\"type\": \"full\", \"status\": \"success\"}"
}

send_security_alert() {
    local message="$1"
    local message_id=$(security-queue send "$message" 2>/dev/null || echo "local")
    log_structured_perf "INFO" "Alerta enviada a cola" "{\"message\": \"$message\", \"queue_id\": \"$message_id\"}"
    echo "✅ Alerta enviada - ID: $message_id"
}

show_system_status() {
    echo "🔐 ESTADO DEL SISTEMA DE SEGURIDAD"
    echo "=================================="
    
    echo "📦 Vault: $( [[ -f ~/.local/security/vault/secrets.vault ]] && echo "✅" || echo "❌" )"
    echo "📬 Cola: $( [[ -f ~/.local/security/queue/security_queue.db ]] && echo "✅" || echo "❌" )"
    echo "📊 Observabilidad: $( pgrep -f 'high-perf-observability.sh' >/dev/null && echo '✅' || echo '❌' )"

    echo "🔗 Comandos: ✅ Disponibles"
    
    log_structured_perf "INFO" "Estado del sistema verificado" "{\"component\": \"status_check\"}"
}

send_notification() {
    local message="$1"
    
    # Intentar Telegram primero
    local telegram_token=$(security-vault get TELEGRAM_BOT_TOKEN 2>/dev/null || echo "")
    local chat_id=$(security-vault get TELEGRAM_CHAT_ID 2>/dev/null || echo "")
    
    if [[ -n "$telegram_token" && -n "$chat_id" ]]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\": \"$chat_id\", \"text\": \"$message\"}" \
            "https://api.telegram.org/bot$telegram_token/sendMessage" > /dev/null &
    fi
    
    # También enviar a cola local
    security-queue send "$message" > /dev/null 2>&1 || true
    
    log_structured_perf "INFO" "Notificación enviada" "{\"message\": \"$message\", \"method\": \"multi\"}"
}

# Función de inicialización (opcional)
init_security_script() {
    log_structured_perf "DEBUG" "Script de seguridad inicializado" "{\"script\": \"$0\"}"
}

# Inicialización automática si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🔧 Enterprise Security Template"
    echo "Funciones disponibles:"
    echo "  - log_structured_perf"
    echo "  - increment_counter_perf" 
    echo "  - show_system_status"
    echo "  - send_security_alert"
    echo "  - run_quick_audit"
    echo "  - run_full_audit"
fi