#!/bin/bash
# verificacion-completa.sh

echo "🔍 VERIFICACIÓN COMPLETA DEL SISTEMA DE SEGURIDAD"
echo "================================================"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

total_checks=0
passed_checks=0
failed_checks=0

check_component() {
    local component="$1"
    local path="$2"
    local desc="$3"
    
    ((total_checks++))
    
    if [[ -e "$path" ]]; then
        echo -e "${GREEN}✅ INSTALADO${NC} - $desc"
        ((passed_checks++))
        return 0
    else
        echo -e "${RED}❌ FALTANTE${NC} - $desc"
        ((failed_checks++))
        return 1
    fi
}

echo ""
echo "📋 VERIFICACIÓN DE COMPONENTES:"
echo "-------------------------------"

# Enlaces simbólicos
check_component "security-vault" "$HOME/bin/security-vault" "Enlace: security-vault"
check_component "security-queue" "$HOME/bin/security-queue" "Enlace: security-queue" 
check_component "security-obs" "$HOME/bin/security-obs" "Enlace: security-obs"
check_component "security-manager" "$HOME/bin/security-manager" "Enlace: security-manager"

# Directorios
check_component "directorio bin" "$HOME/.local/security/bin" "Directorio: bin/"
check_component "directorio vault" "$HOME/.local/security/vault" "Directorio: vault/"
check_component "directorio queue" "$HOME/.local/security/queue" "Directorio: queue/"
check_component "directorio logs" "$HOME/.local/security/logs" "Directorio: logs/"
check_component "directorio config" "$HOME/.local/security/config" "Directorio: config/"

# Archivos críticos
check_component "security-manager.sh" "$HOME/.local/security/bin/security-manager.sh" "Archivo: security-manager.sh"
check_component "enterprise-vault.sh" "$HOME/.local/security/bin/enterprise-vault.sh" "Archivo: enterprise-vault.sh"
check_component "sqlite-queue.sh" "$HOME/.local/security/bin/sqlite-queue.sh" "Archivo: sqlite-queue.sh"
check_component "enterprise-script-template.sh" "$HOME/.local/security/bin/enterprise-script-template.sh" "Archivo: enterprise-script-template.sh"
check_component "high-perf-observability.sh" "$HOME/.local/security/bin/high-perf-observability.sh" "Archivo: high-perf-observability.sh"

# Procesos
echo ""
echo "⚙️  ESTADO DE PROCESOS:"
echo "----------------------"
((total_checks++))
if pgrep -f 'obs.log' >/dev/null; then
    echo -e "${GREEN}✅ EJECUTÁNDOSE${NC} - security-obs"
    ((passed_checks++))
else
    echo -e "${RED}❌ INACTIVO${NC} - security-obs"
    ((failed_checks++))
fi

# Verificación de funcionalidad
echo ""
echo "🔧 VERIFICACIÓN DE FUNCIONALIDAD:"
echo "--------------------------------"

((total_checks++))
if command -v security-manager >/dev/null 2>&1; then
    echo -e "${GREEN}✅ FUNCIONAL${NC} - security-manager command"
    ((passed_checks++))
else
    echo -e "${RED}❌ NO FUNCIONAL${NC} - security-manager command"
    ((failed_checks++))
fi

# Resumen final
echo ""
echo "📊 RESUMEN DE VERIFICACIÓN:"
echo "--------------------------"
echo -e "Total de verificaciones: $total_checks"
echo -e "${GREEN}Aprobados: $passed_checks${NC}"
echo -e "${RED}Fallidos: $failed_checks${NC}"

echo ""
if [[ $failed_checks -eq 0 ]]; then
    echo -e "${GREEN}🎉 ¡SISTEMA COMPLETAMENTE OPERATIVO!${NC}"
    echo "   Todos los componentes están instalados y funcionando."
elif [[ $failed_checks -lt 3 ]]; then
    echo -e "${YELLOW}⚠️  SISTEMA PARCIALMENTE OPERATIVO${NC}"
    echo "   Algunos componentes faltan pero el sistema principal funciona."
    echo "   Ejecute './install-desde-cero.sh' para reparar."
else
    echo -e "${RED}❌ SISTEMA INCOMPLETO${NC}"
    echo "   Faltan componentes críticos."
    echo "   Ejecute './desinstalar-completo.sh' seguido de './install-desde-cero.sh'"
fi

echo ""
echo "💡 Comandos disponibles:"
echo "   security-manager status"
echo "   security-vault list" 
echo "   security-queue status"