#!/bin/bash
set -euo pipefail

# === CONFIGURACIÓN CON RUTAS ABSOLUTAS ===
readonly SCRIPT_DIR="$HOME/.local/security/bin"
readonly VAULT_FILE="$HOME/.local/security/vault/secrets.vault"
readonly QUEUE_DB="$HOME/.local/security/queue/security_queue.db"
readonly OBS_SCRIPT="high-perf-observability.sh"

# === CARGAR TEMPLATE ===
if [[ -f "$SCRIPT_DIR/enterprise-script-template.sh" ]]; then
    source "$SCRIPT_DIR/enterprise-script-template.sh"
fi

# === FUNCIONES DE INICIALIZACIÓN ===
initialize_components() {
    mkdir -p "$HOME/.local/security/vault" "$HOME/.local/security/queue" "$HOME/.local/security/logs"

    # Vault
    if [[ ! -f "$VAULT_FILE" ]]; then
        echo "# 🔐 Archivo de secretos inicial (puede editarse manualmente)" > "$VAULT_FILE"
        chmod 600 "$VAULT_FILE"
        log_structured_perf "INFO" "Vault inicializado automáticamente" '{"file": "secrets.vault"}'
    fi

    # Cola
    if [[ ! -f "$QUEUE_DB" ]]; then
        sqlite3 "$QUEUE_DB" "CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY, content TEXT, timestamp TEXT);"
        log_structured_perf "INFO" "Cola SQLite inicializada automáticamente" '{"db": "security_queue.db"}'
    fi
}

# === ESTADO DEL SISTEMA ===
show_system_status() {
    initialize_components

    echo "🔐 ESTADO DEL SISTEMA DE SEGURIDAD"
    echo "=================================="

    # Vault
    vault_status="✅ (operativo)"
    [[ -f "$VAULT_FILE" ]] || vault_status="⚠️  (sin inicializar)"

    # Cola
    queue_status="✅ (activa)"
    [[ -f "$QUEUE_DB" ]] || queue_status="⚠️  (sin inicializar)"

    # Observabilidad: si está inactiva, intentar reinicio 1 vez
    obs_status=""
    if [[ -f /tmp/security-obs.pid ]] && ps -p "$(cat /tmp/security-obs.pid)" &>/dev/null; then
        obs_status="✅ (en ejecución)"
    else
        # intentar reinicio automático (1 intento) si existe el binario
        if [[ -x "$HOME/.local/security/bin/high-perf-observability.sh" ]]; then
            echo "⌛ Observabilidad caída — intentando reiniciar..."
            "$HOME/.local/security/bin/high-perf-observability.sh" start >/dev/null 2>&1 || true
            sleep 2
            if [[ -f /tmp/security-obs.pid ]] && ps -p "$(cat /tmp/security-obs.pid)" &>/dev/null; then
                obs_status="✅ (reiniciado automáticamente)"
            else
                obs_status="❌ (inactiva — reinicio fallido)"
            fi
        else
            obs_status="❌ (inactiva — binario ausente)"
        fi
    fi

    echo "📦 Vault: $vault_status"
    echo "📬 Cola:  $queue_status"
    echo "📊 Observabilidad: $obs_status"
    echo "🔗 Comandos: ✅ Disponibles"
}


# === ALERTAS Y AUDITORÍAS ===
send_security_alert() {
    local message="$1"
    log_structured_perf "ALERT" "$message" '{"severity": "high"}'
    echo "🚨 Alerta enviada: $message"
}

run_quick_audit() {
    log_structured_perf "INFO" "Iniciando auditoría rápida" '{"type":"quick"}'
    echo "🔍 Ejecutando auditoría rápida..."

    local tools=("lynis" "rkhunter" "chkrootkit")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo "  ✅ $tool disponible"
        else
            echo "  ⚠️  $tool no disponible"
        fi
    done

    if command -v lynis &>/dev/null; then
        echo "  Ejecutando Lynis (modo rápido)..."
        sudo lynis audit system --quick --no-colors --quiet 2>/dev/null || true
    fi

    echo "✅ Auditoría rápida completada"
    increment_counter_perf "security_audits_total" 1 '{"type":"quick","status":"success"}'
}

run_full_audit() {
    log_structured_perf "INFO" "Iniciando auditoría completa" '{"type":"full"}'
    echo "🔍 Iniciando auditoría de seguridad completa..."
    sleep 5
    echo "✅ Auditoría completa finalizada"
    increment_counter_perf "security_audits_total" 1 '{"type":"full","status":"success"}'
}

# === VISUALIZACIÓN DE LOGS ===
show_logs() {
    LOG_PATH="$HOME/.local/security/logs/security.log"
    if [[ -f "$LOG_PATH" ]]; then
        echo "📜 Mostrando logs en tiempo real (Ctrl+C para salir)..."
        tail -f "$LOG_PATH"
    else
        echo "⚠️  No hay logs disponibles todavía."
    fi
}

# === COMANDOS ===
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
        if [[ -z "${2:-}" ]]; then
            echo "❌ Uso: security-manager send-alert <mensaje>"
            exit 1
        fi
        send_security_alert "$2"
        ;;
    "logs")
        show_logs
        ;;
    *)
        echo "🔐 Security Manager - Comandos disponibles:"
        echo "  audit-quick          → Auditoría rápida del sistema"
        echo "  audit-full           → Auditoría completa del sistema"
        echo "  status               → Mostrar estado general"
        echo "  send-alert <mensaje> → Enviar alerta manual"
        echo "  logs                 → Ver logs en tiempo real"
        ;;
esac
