#!/bin/bash
# uninstall.sh

set -euo pipefail

readonly INSTALL_DIR="$HOME/.local/security"
readonly BIN_DIR="$HOME/bin"

log() {
    echo "[UNINSTALL] $1" >&2
}

remove_symlinks() {
    log "Removiendo enlaces simbólicos..."
    
    local binaries=("security-vault" "security-queue" "security-obs" "security-manager")
    
    for binary in "${binaries[@]}"; do
        if [[ -L "$BIN_DIR/$binary" ]]; then
            rm -f "$BIN_DIR/$binary"
            log "  Removido: $BIN_DIR/$binary"
        fi
    done
}

remove_crontab_entries() {
    log "Removiendo entradas de crontab..."
    
    if crontab -l &> /dev/null; then
        crontab -l | grep -v "security-monitoring-enterprise" | crontab -
        log "  Entradas de crontab removidas"
    fi
}

stop_services() {
    log "Deteniendo servicios..."
    
    # Detener daemon de observabilidad
    pkill -f "security-obs" || true
}

remove_installation() {
    local keep_data="${1:-no}"
    
    if [[ "$keep_data" == "keep-data" ]]; then
        log "Manteniendo datos en $INSTALL_DIR"
        return 0
    fi
    
    log "Removiendo instalación..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log "  Directorio removido: $INSTALL_DIR"
    fi
}

main() {
    echo "🔴 DESINSTALANDO SECURITY MONITORING ENTERPRISE"
    echo "=============================================="
    
    read -p "¿Mantener datos de configuración? (y/N): " -r keep_data
    
    stop_services
    remove_symlinks
    remove_crontab_entries
    
    if [[ "$keep_data" =~ ^[Yy]$ ]]; then
        remove_installation "keep-data"
        echo "✅ Datos mantenidos en $INSTALL_DIR"
    else
        remove_installation
        echo "✅ Todos los datos removidos"
    fi
    
    echo ""
    echo "🎯 Desinstalación completada"
}

main "$@"