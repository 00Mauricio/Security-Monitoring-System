#!/bin/bash
set -euo pipefail

echo "🗑️  DESINSTALACIÓN COMPLETA Y VERIFICADA DEL SISTEMA DE SEGURIDAD"
echo "================================================================"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Función de logging mejorada
log() {
    local level="$1"
    local message="$2"
    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅${NC} $message" ;;
        "ERROR") echo -e "${RED}❌${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️${NC} $message" ;;
        "INFO") echo -e "${YELLOW}ℹ️${NC} $message" ;;
    esac
}

# 1. INVENTARIO COMPLETO PRE-DESINSTALACIÓN
echo ""
log "INFO" "📋 REALIZANDO INVENTARIO COMPLETO PRE-DESINSTALACIÓN"
echo "--------------------------------------------------------"

total_items=0
found_items=()

# Verificar enlaces simbólicos
log "INFO" "Buscando enlaces simbólicos..."
set +e
for link in security-vault security-queue security-obs security-manager; do
    if [[ -L "$HOME/bin/$link" ]]; then
        log "WARNING" "Encontrado: $HOME/bin/$link"
        found_items+=("$HOME/bin/$link")
        ((total_items++))
    fi
done
set -e

# Verificar directorios y archivos
log "INFO" "Buscando directorios y archivos..."
declare -a paths_to_check=(
    "$HOME/.local/security"
    "$HOME/.local/security/bin"
    "$HOME/.local/security/vault" 
    "$HOME/.local/security/queue"
    "$HOME/.local/security/logs"
    "$HOME/.local/security/config"
    "/tmp/security-obs.sock"
    "/tmp/security-obs.pid"
)

for path in "${paths_to_check[@]}"; do
    if [[ -e "$path" ]]; then
        log "WARNING" "Encontrado: $path"
        found_items+=("$path")
        ((total_items++))
    fi
done

# Verificar procesos
log "INFO" "Buscando procesos activos..."
if pgrep -f "security-obs" >/dev/null; then
    log "WARNING" "Proceso security-obs en ejecución"
    found_items+=("security-obs process")
    ((total_items++))
fi

if pgrep -f "python3.*security" >/dev/null; then
    log "WARNING" "Proceso Python security en ejecución"
    found_items+=("python security process")
    ((total_items++))
fi

# Verificar crontab
log "INFO" "Buscando entradas en crontab..."
if crontab -l 2>/dev/null | grep -q "SECURITY MONITORING ENTERPRISE"; then
    log "WARNING" "Entradas security en crontab"
    found_items+=("crontab entries")
    ((total_items++))
fi

# Resumen del inventario
echo ""
if [[ $total_items -eq 0 ]]; then
    log "SUCCESS" "No se encontraron componentes instalados. El sistema está limpio."
    exit 0
else
    log "WARNING" "Se encontraron $total_items componentes para eliminar:"
    printf '   - %s\n' "${found_items[@]}"
fi

# 2. CONFIRMACIÓN DE DESINSTALACIÓN
echo ""
log "WARNING" "⚠️  ESTA ACCIÓN ELIMINARÁ COMPLETAMENTE EL SISTEMA DE SEGURIDAD"
read -p "   ¿Continuar con la desinstalación completa? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    log "INFO" "Desinstalación cancelada por el usuario."
    exit 0
fi

# 3. PROCESO DE DESINSTALACIÓN MEJORADO
echo ""
log "INFO" "🔴 INICIANDO DESINSTALACIÓN COMPLETA..."
echo "--------------------------------------------"

# 3.1 Detener procesos de forma más agresiva
log "INFO" "Deteniendo todos los procesos relacionados..."
pkill -f "security-obs" 2>/dev/null && log "SUCCESS" "Proceso security-obs detenido" || log "INFO" "Proceso security-obs no encontrado"
pkill -f "python3.*security" 2>/dev/null && log "SUCCESS" "Procesos Python detenidos" || log "INFO" "Procesos Python no encontrados"
pkill -f "security-manager" 2>/dev/null && log "SUCCESS" "Procesos security-manager detenidos" || log "INFO" "Procesos security-manager no encontrados"

# Pequeña pausa para asegurar que los procesos se detengan
sleep 2

# 3.2 Eliminar enlaces simbólicos de forma exhaustiva
log "INFO" "Eliminando enlaces simbólicos..."
for link in security-vault security-queue security-obs security-manager security-monitoring; do
    if [[ -L "$HOME/bin/$link" ]]; then
        rm -f "$HOME/bin/$link" && log "SUCCESS" "Enlace $link eliminado" || log "ERROR" "Error eliminando $link"
    fi
done

# 3.3 Eliminar entradas de crontab de forma más robusta
log "INFO" "Limpiando crontab..."
if command -v crontab >/dev/null 2>&1; then
    if crontab -l 2>/dev/null | grep -q "SECURITY"; then
        crontab -l 2>/dev/null | grep -v "SECURITY" | grep -v "security" | crontab -
        log "SUCCESS" "Entradas security eliminadas de crontab"
    else
        log "INFO" "No se encontraron entradas security en crontab"
    fi
fi

# 3.4 Eliminar directorios de forma recursiva y segura
log "INFO" "Eliminando directorios y archivos..."
if [[ -d "$HOME/.local/security" ]]; then
    rm -rf "$HOME/.local/security" && log "SUCCESS" "Directorio security eliminado completamente" || log "ERROR" "Error eliminando directorio security"
else
    log "INFO" "Directorio security no encontrado"
fi

# 3.5 Limpieza exhaustiva de archivos temporales
log "INFO" "Limpiando archivos temporales..."
rm -f /tmp/security-*.sock 2>/dev/null && log "SUCCESS" "Sockets temporales eliminados" || log "INFO" "No se encontraron sockets"
rm -f /tmp/security-*.pid 2>/dev/null && log "SUCCESS" "Archivos PID eliminados" || log "INFO" "No se encontraron archivos PID"
rm -f /tmp/security-*.log 2>/dev/null && log "SUCCESS" "Logs temporales eliminados" || log "INFO" "No se encontraron logs temporales"
rm -f /tmp/security-* 2>/dev/null && log "SUCCESS" "Otros archivos temporales eliminados" || log "INFO" "No se encontraron otros archivos temporales"

# 4. VERIFICACIÓN POST-DESINSTALACIÓN EXHAUSTIVA
echo ""
log "INFO" "🔍 VERIFICACIÓN POST-DESINSTALACIÓN EXHAUSTIVA"
echo "---------------------------------------------------"

remaining_items=0
remaining_list=()

# Verificar enlaces residuales
for link in security-vault security-queue security-obs security-manager; do
    if [[ -L "$HOME/bin/$link" ]]; then
        log "ERROR" "ENLACE RESIDUAL: $HOME/bin/$link"
        remaining_list+=("$HOME/bin/$link")
        ((remaining_items++))
    fi
done

# Verificar directorios residuales
if [[ -d "$HOME/.local/security" ]]; then
    log "ERROR" "DIRECTORIO RESIDUAL: $HOME/.local/security"
    remaining_list+=("$HOME/.local/security")
    ((remaining_items++))
fi

# Verificar procesos residuales
if pgrep -f "security-obs" >/dev/null; then
    log "ERROR" "PROCESO RESIDUAL: security-obs aún en ejecución"
    remaining_list+=("security-obs process")
    ((remaining_items++))
fi

# Verificar archivos temporales residuales
for temp_file in /tmp/security-*; do
    if [[ -e "$temp_file" ]]; then
        log "ERROR" "ARCHIVO TEMPORAL RESIDUAL: $temp_file"
        remaining_list+=("$temp_file")
        ((remaining_items++))
    fi
done

# 5. RESULTADO FINAL
echo ""
if [[ $remaining_items -eq 0 ]]; then
    log "SUCCESS" "🎉 ¡DESINSTALACIÓN COMPLETADA EXITOSAMENTE!"
    log "SUCCESS" "Todos los componentes fueron eliminados correctamente."
    log "SUCCESS" "El sistema está listo para una instalación limpia."
else
    log "ERROR" "⚠️  DESINSTALACIÓN INCOMPLETA"
    log "ERROR" "Quedaron $remaining_items elementos sin eliminar:"
    printf '   - %s\n' "${remaining_list[@]}"
    echo ""
    log "WARNING" "RECOMENDACIÓN: Ejecute este script nuevamente o elimine manualmente los elementos restantes."
fi

echo ""
log "INFO" "💡 Para una reinstalación limpia ejecute: ./install.sh"