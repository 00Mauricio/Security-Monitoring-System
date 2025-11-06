#!/bin/bash
set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
readonly INSTALL_DIR="$HOME/.local/security"
readonly BIN_DIR="$HOME/bin"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    local level="$1"
    local message="$2"
    local color=""
    
    case "$level" in
        "INFO") color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
        "WARNING") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
    esac
    
    echo -e "${color}[$level]${NC} $message" >&2
}

check_dependencies() {
    log "INFO" "Verificando dependencias..."
    
    local missing=()
    
    # Dependencias críticas
    for dep in bash sqlite3 openssl curl jq python3; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR" "Dependencias faltantes: ${missing[*]}"
        log "INFO" "Instala con: sudo apt-get install ${missing[*]}"
        return 1
    fi
    
    # Verificar versión de Bash
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log "ERROR" "Bash 4.0+ requerido. Actual: $BASH_VERSION"
        return 1
    fi
    
    log "SUCCESS" "Todas las dependencias satisfechas"
}

create_directories() {
    log "INFO" "Creando estructura de directorios..."
    
    local dirs=(
        "$INSTALL_DIR"
        "$INSTALL_DIR/bin"
        "$INSTALL_DIR/vault"
        "$INSTALL_DIR/queue" 
        "$INSTALL_DIR/logs"
        "$INSTALL_DIR/config"
        "$INSTALL_DIR/helpers"
        "$BIN_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log "INFO" "  Creado: $dir"
    done
}

install_scripts() {
    log "INFO" "Instalando scripts..."
    
    # Copiar scripts principales
    cp "$SCRIPT_DIR/src/bin/"* "$INSTALL_DIR/bin/"
    
    # Hacer ejecutables
    chmod +x "$INSTALL_DIR/bin/"*.sh
    
    # Crear enlaces simbólicos
    local binaries=(
        "enterprise-vault.sh:security-vault"
        "sqlite-queue.sh:security-queue" 
        "high-perf-observability.sh:security-obs"
        "security-manager.sh:security-manager"
    )
    
    for binary in "${binaries[@]}"; do
        local source="${binary%:*}"
        local target="${binary#*:}"
        ln -sf "$INSTALL_DIR/bin/$source" "$BIN_DIR/$target"
        log "INFO" "  Enlace creado: $BIN_DIR/$target"
    done
    
    # Configuración por defecto
    if [[ -f "$SCRIPT_DIR/src/config/default.conf" ]]; then
        cp "$SCRIPT_DIR/src/config/default.conf" "$INSTALL_DIR/config/"
    fi
}

initialize_components() {
    log "INFO" "Inicializando componentes..."
    
    # Inicializar vault
    if "$BIN_DIR/security-vault" init; then
        log "SUCCESS" "Vault inicializado"
    else
        log "ERROR" "Error inicializando vault"
        return 1
    fi
    
    # Inicializar queue
    if "$BIN_DIR/security-queue" init; then
        log "SUCCESS" "Cola SQLite inicializada"
    else
        log "ERROR" "Error inicializando cola"
        return 1
    fi
    
    # Iniciar daemon de observabilidad
    if "$BIN_DIR/security-obs" start; then
        log "SUCCESS" "Daemon de observabilidad iniciado"
    else
        log "WARNING" "No se pudo iniciar daemon de observabilidad"
    fi
}

setup_crontab() {
    log "INFO" "Configurando tareas programadas..."
    
    if [[ -f "$SCRIPT_DIR/examples/crontab.example" ]]; then
        # Backup del crontab actual
        if crontab -l &> /dev/null; then
            crontab -l > "/tmp/crontab_backup_$(date +%s)"
        fi
        
        # Agregar nuestras entradas
        (
            crontab -l 2>/dev/null | grep -v "# security-monitoring-enterprise" || true
            echo ""
            echo "# security-monitoring-enterprise - Instalado $(date)"
            cat "$SCRIPT_DIR/examples/crontab.example"
        ) | crontab -
        
        log "SUCCESS" "Crontab configurado"
    else
        log "WARNING" "Ejemplo de crontab no encontrado"
    fi
}

setup_telegram() {
    log "INFO" "Configuración opcional de Telegram"
    echo -n "¿Configurar Telegram ahora? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -n "Token del bot de Telegram: "
        read -r bot_token
        echo -n "Chat ID: "
        read -r chat_id
        
        if "$BIN_DIR/security-vault" encrypt TELEGRAM_BOT_TOKEN "$bot_token" && \
           "$BIN_DIR/security-vault" encrypt TELEGRAM_CHAT_ID "$chat_id"; then
            log "SUCCESS" "Telegram configurado correctamente"
        else
            log "ERROR" "Error configurando Telegram"
        fi
    fi
}

post_install_check() {
    log "INFO" "Realizando verificación post-instalación..."
    
    local errors=0
    
    # Verificar comandos
    for cmd in security-vault security-queue security-obs security-manager; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Comando no encontrado: $cmd"
            ((errors++))
        fi
    done
    
    # Verificar archivos críticos
    local critical_files=(
        "$INSTALL_DIR/bin/enterprise-vault.sh"
        "$INSTALL_DIR/bin/sqlite-queue.sh"
        "$INSTALL_DIR/vault/keys/current.key"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log "ERROR" "Archivo crítico faltante: $file"
            ((errors++))
        fi
    done
    
    # Verificar daemon
    if ! pgrep -f "security-obs" > /dev/null; then
        log "WARNING" "Daemon de observabilidad no está corriendo"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log "SUCCESS" "✅ Instalación completada exitosamente!"
        return 0
    else
        log "ERROR" "❌ Instalación completada con $errors errores"
        return 1
    fi
}

show_next_steps() {
    cat << EOF

🎉 ¡INSTALACIÓN COMPLETADA!

📋 Próximos pasos recomendados:

1. Probar el sistema:
   security-manager status
   security-manager send-alert "Test del sistema"

2. Configurar auditorías (si no se hizo durante instalación):
   security-vault encrypt TELEGRAM_BOT_TOKEN "tu_token"
   security-vault encrypt TELEGRAM_CHAT_ID "tu_chat_id"

3. Verificar tareas programadas:
   crontab -l

4. Monitorear logs:
   security-manager logs

📚 Documentación:
   Ver examples/ para configuraciones avanzadas
   Ejecutar 'security-manager' sin argumentos para ayuda

💡 Comandos útiles:
   security-manager audit-quick    # Auditoría rápida
   security-queue status          # Estado de colas
   security-vault list            # Listar secretos

EOF
}

main() {
    log "INFO" "Iniciando instalación de Security Monitoring Enterprise..."
    log "INFO" "Directorio de instalación: $INSTALL_DIR"
    
    # Verificar que estamos en el directorio correcto
    if [[ ! -f "$SCRIPT_DIR/README.md" ]]; then
        log "ERROR" "Ejecutar desde el directorio del repositorio"
        exit 1
    fi
    
    # Ejecutar pasos de instalación
    check_dependencies || exit 1
    create_directories
    install_scripts
    initialize_components || exit 1
    setup_crontab
    setup_telegram
    post_install_check
    show_next_steps
}

# Ejecutar instalación
main "$@"