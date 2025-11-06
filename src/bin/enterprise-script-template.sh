#!/bin/bash
# enterprise-script-template.sh
set -euo pipefail
IFS=$'\n\t'

# === CONFIGURACIÓN ROBUSTA ===
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOCK_DIR="/tmp/security.locks"
readonly PID_FILE="$LOCK_DIR/${SCRIPT_NAME}.pid"

# === INICIALIZACIÓN SEGURA ===
init_enterprise_script() {
    mkdir -p "$LOCK_DIR"
    
    # Adquirir lock con timeout
    if ! acquire_lock_with_timeout 30; then
        log_structured_perf "ERROR" "Failed to acquire lock after 30s" "{\"script\": \"$SCRIPT_NAME\"}"
        exit 1
    fi
    
    # Validar entorno crítico
    validate_critical_dependencies
    check_disk_space
}

acquire_lock_with_timeout() {
    local timeout="$1"
    local start_time=$(date +%s)
    
    while [[ $(($(date +%s) - start_time)) -lt $timeout ]]; do
        if mkdir "$PID_FILE.lock" 2>/dev/null; then
            echo $$ > "$PID_FILE"
            rmdir "$PID_FILE.lock"
            return 0
        fi
        
        # Verificar si el proceso dueño del lock sigue vivo
        local owner_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$owner_pid" ]] && ! kill -0 "$owner_pid" 2>/dev/null; then
            rm -f "$PID_FILE"
            continue
        fi
        
        sleep 1
    done
    return 1
}

validate_critical_dependencies() {
    local deps=("sqlite3" "openssl" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_structured_perf "ERROR" "Missing critical dependencies" "{\"dependencies\": \"${missing[*]}\"}"
        exit 1
    fi
}

check_disk_space() {
    local available_mb=$(df /tmp --output=avail | tail -1 | awk '{print $1/1024}')
    if [[ $available_mb -lt 100 ]]; then
        log_structured_perf "ERROR" "Insufficient disk space" "{\"available_mb\": $available_mb}"
        exit 1
    fi
}

# === EJECUCIÓN SEGURA DE COMANDOS ===
run_privileged_enterprise() {
    local command="$1"
    local reason="$2"
    
    log_structured_perf "INFO" "Executing privileged command" "{\"reason\": \"$reason\", \"command\": \"$command\"}"
    
    # Verificar comando seguro
    if ! validate_command "$command"; then
        log_structured_perf "ERROR" "Command validation failed" "{\"command\": \"$command\"}"
        return 1
    fi
    
    # Ejecutar con timeout
    timeout 300 sudo -n "$command"
    local exit_code=$?
    
    if [[ $exit_code -eq 124 ]]; then
        log_structured_perf "ERROR" "Privileged command timed out" "{\"command\": \"$command\"}"
    elif [[ $exit_code -ne 0 ]]; then
        log_structured_perf "ERROR" "Privileged command failed" "{\"command\": \"$command\", \"exit_code\": $exit_code}"
    fi
    
    return $exit_code
}

validate_command() {
    local command="$1"
    
    # Lista blanca de comandos seguros
    local safe_commands=("lynis" "rkhunter" "chkrootkit" "aide.wrapper" "apt-get" "systemctl")
    
    for safe_cmd in "${safe_commands[@]}"; do
        if [[ "$command" == "$safe_cmd"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# === CLEANUP ROBUSTO ===
cleanup_enterprise() {
    local exit_code=$?
    
    # Liberar lock
    rm -f "$PID_FILE"
    
    # Log de finalización
    if [[ $exit_code -eq 0 ]]; then
        log_structured_perf "INFO" "Script completed successfully" "{\"script\": \"$SCRIPT_NAME\", \"duration\": $SECONDS}"
    else
        log_structured_perf "ERROR" "Script failed" "{\"script\": \"$SCRIPT_NAME\", \"exit_code\": $exit_code, \"duration\": $SECONDS}"
    fi
    
    exit $exit_code
}

trap cleanup_enterprise EXIT INT TERM

# === EJECUCIÓN PRINCIPAL ===
main() {
    init_enterprise_script
    
    # Tu lógica aquí
    log_structured_perf "INFO" "Starting security operation" "{\"operation\": \"$1\"}"
    
    # Ejemplo de uso
    local telegram_token=$(get_secret_enterprise "TELEGRAM_BOT_TOKEN")
    # ... resto de la lógica
}

# Ejecutar sólo si es el script principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi