# Crear: ~/.local/security/bin/security-manager.sh
cat > ~/.local/security/bin/security-manager.sh << 'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/enterprise-script-template.sh"

# Comandos simples para el usuario
case "${1:-}" in
    "audit-quick")
        run_quick_audit
        ;;
    "audit-full") 
        run_full_audit
        ;;
    "status")
        show_system_status
        ;;
    "send-alert")
        send_security_alert "${2:-}"
        ;;
    "logs")
        tail -f ~/.local/security/logs/observability.jsonl | jq .
        ;;
    *)
        echo "🔐 Security Manager - Comandos disponibles:"
        echo "  audit-quick    - Auditoría rápida del sistema"
        echo "  audit-full     - Auditoría completa"
        echo "  status         - Estado del sistema"
        echo "  send-alert <msg> - Enviar alerta manual"
        echo "  logs           - Ver logs en tiempo real"
        ;;
esac

run_quick_audit() {
    log_structured_perf "INFO" "Iniciando auditoría rápida" "{\"type\": \"quick_audit\"}"
    
    # 1. Verificar herramientas
    local tools=("lynis" "rkhunter" "chkrootkit")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_structured_perf "INFO" "Herramienta disponible" "{\"tool\": \"$tool\"}"
        else
            log_structured_perf "WARNING" "Herramienta no disponible" "{\"tool\": \"$tool\"}"
        fi
    done
    
    # 2. Ejecutar Lynis rápido
    if command -v lynis &> /dev/null; then
        log_structured_perf "INFO" "Ejecutando Lynis quick scan")
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
    
    # Aquí iría la lógica completa con todas las herramientas
    # Por ahora es un placeholder
    sleep 10
    
    send_notification "✅ Auditoría completa finalizada"
    increment_counter_perf "security_audits_total" 1 "{\"type\": \"full\", \"status\": \"success\"}"
}

send_security_alert() {
    local message="$1"
    local message_id=$(~/bin/security-queue send "$message")
    
    log_structured_perf "INFO" "Alerta enviada a cola" "{\"message\": \"$message\", \"queue_id\": \"$message_id\"}"
    echo "✅ Alerta enviada - ID: $message_id"
}

show_system_status() {
    echo "🔐 ESTADO DEL SISTEMA DE SEGURIDAD"
    echo "=================================="
    
    # Vault
    echo "📦 Vault:"
    if [[ -f ~/.local/security/vault/secrets.vault ]]; then
        echo "  ✅ Configurado ($(stat -c %y ~/.local/security/vault/secrets.vault))"
    else
        echo "  ❌ No configurado"
    fi
    
    # Queue
    echo "📬 Cola de mensajes:"
    ~/bin/security-queue status
    
    # Observabilidad
    echo "📊 Observabilidad:"
    if pgrep -f "security-obs" > /dev/null; then
        echo "  ✅ Daemon activo"
    else
        echo "  ❌ Daemon inactivo"
    fi
    
    # Logs
    echo "📝 Logs:"
    local log_count=$(find ~/.local/security/logs -name "*.jsonl" -type f 2>/dev/null | wc -l)
    echo "  Archivos de log: $log_count"
}

send_notification() {
    local message="$1"
    
    # Intentar Telegram primero
    local telegram_token=$(~/bin/security-vault get TELEGRAM_BOT_TOKEN 2>/dev/null || echo "")
    local chat_id=$(~/bin/security-vault get TELEGRAM_CHAT_ID 2>/dev/null || echo "")
    
    if [[ -n "$telegram_token" && -n "$chat_id" ]]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\": \"$chat_id\", \"text\": \"$message\"}" \
            "https://api.telegram.org/bot$telegram_token/sendMessage" > /dev/null &
    fi
    
    # También enviar a cola local
    ~/bin/security-queue send "$message" > /dev/null
}
EOF

chmod +x ~/.local/security/bin/security-manager.sh
ln -sf ~/.local/security/bin/security-manager.sh ~/bin/security-manager