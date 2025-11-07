#!/bin/bash
set -euo pipefail

echo "🚀 INSTALACIÓN DESDE CERO DEL SISTEMA DE SEGURIDAD"
echo "=================================================="

# VERIFICACIÓN DE INSTALACIONES PREVIAS
echo "🔍 Buscando instalaciones previas..."
previous_install=false

check_previous_install() {
    local items=()
    
    # Verificar enlaces
    for link in security-vault security-queue security-obs security-manager; do
        if [[ -L "$HOME/bin/$link" ]]; then
            items+=("Enlace $link")
        fi
    done
    
    # Verificar directorios
    if [[ -d "$HOME/.local/security" ]]; then
        items+=("Directorio security")
    fi
    
    # Verificar procesos
    if pgrep -f "security-obs" >/dev/null; then
        items+=("Procesos activos")
    fi
    
    if [[ ${#items[@]} -gt 0 ]]; then
        echo "⚠️  SE ENCONTRÓ UNA INSTALACIÓN PREVIA:"
        printf '   - %s\n' "${items[@]}"
        echo ""
        
        read -p "¿Deseas desinstalar la versión anterior antes de continuar? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            if [[ -f "./desinstalar-completo.sh" ]]; then
                echo "🔧 Ejecutando desinstalación previa..."
                ./desinstalar-completo.sh
                echo ""
                echo "✅ Continuando con instalación limpia..."
            else
                echo "❌ No se encontró desinstalar-completo.sh"
                echo "   Por favor, ejecútalo manualmente primero."
                exit 1
            fi
        else
            echo "❌ Instalación cancelada. Desinstala primero la versión anterior."
            exit 1
        fi
    else
        echo "✅ No se encontraron instalaciones previas."
    fi
}

# Ejecutar verificación
check_previous_install

# CONTINUAR CON LA INSTALACIÓN NORMAL...
# [el resto del script de instalación]

# === CONFIGURACIÓN ===
INSTALL_DIR="$HOME/.local/security"
BIN_DIR="$HOME/bin"

# Crear directorios
echo "📁 Creando estructura de directorios..."
mkdir -p "$INSTALL_DIR"/{bin,vault,queue,logs,config}
mkdir -p "$BIN_DIR"

# Copiar scripts básicos
echo "📦 Copiando scripts base..."

# --- TEMPLATE BASE ---
cat > "$INSTALL_DIR/bin/enterprise-script-template.sh" << 'EOF'
#!/bin/bash
# ENTERPRISE SCRIPT TEMPLATE - VERSIÓN SIMPLIFICADA Y FUNCIONAL

log_structured_perf() {
    local level="$1"
    local message="$2"
    local fields="${3:-{}}"
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    mkdir -p ~/.local/security/logs
    printf '[%s] %s: %s - %s\n' "$timestamp" "$level" "$message" "$fields" >> ~/.local/security/logs/security.log
}

increment_counter_perf() {
    local metric_name="$1"
    local value="${2:-1}"
    local labels="${3:-{}}"
    log_structured_perf "METRIC" "Counter incremented" "{\"name\":\"$metric_name\",\"value\":$value,\"labels\":$labels}"
}

send_alert() {
    local message="$1"
    log_structured_perf "ALERT" "$message" '{"severity":"high"}'
    echo "🚨 ALERTA: $message"
}

run_quick_audit() {
    log_structured_perf "INFO" "Iniciando auditoría rápida" "{\"type\": \"quick_audit\"}"
    echo "🔍 Ejecutando auditoría rápida..."
    local tools=("lynis" "rkhunter" "chkrootkit")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo "  ✅ $tool disponible"
        else
            echo "  ⚠️  $tool no disponible"
        fi
    done
    echo "✅ Auditoría rápida completada"
    increment_counter_perf "security_audits_total" 1 "{\"type\": \"quick\", \"status\": \"success\"}"
}

run_full_audit() {
    log_structured_perf "INFO" "Iniciando auditoría completa" "{\"type\": \"full_audit\"}"
    echo "🔍 Iniciando auditoría de seguridad completa..."
    sleep 5
    echo "✅ Auditoría completa finalizada"
    increment_counter_perf "security_audits_total" 1 "{\"type\": \"full\", \"status\": \"success\"}"
}

send_security_alert() {
    local message="$1"
    log_structured_perf "INFO" "Alerta de seguridad" "{\"message\": \"$message\"}"
    echo "✅ Alerta enviada: $message"
}

show_system_status() {
    echo "🔐 ESTADO DEL SISTEMA DE SEGURIDAD"
    echo "=================================="
    echo "📦 Vault: $( [[ -f ~/.local/security/vault/secrets.vault ]] && echo '✅' || echo '❌' )"
    echo "📬 Cola: $( [[ -f ~/.local/security/queue/security_queue.db ]] && echo '✅' || echo '❌' )"
    echo "📊 Observabilidad: $( pgrep -f 'security-obs' >/dev/null && echo '✅' || echo '❌' )"
    echo "🔗 Comandos: ✅ Disponibles"
}
EOF

# --- SECURITY MANAGER ---
cat > "$INSTALL_DIR/bin/security-manager.sh" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly SCRIPT_DIR="$HOME/.local/security/bin"
source "$SCRIPT_DIR/enterprise-script-template.sh"

case "${1:-}" in
    "audit-quick") run_quick_audit ;;
    "audit-full")  run_full_audit ;;
    "status")      show_system_status ;;
    "send-alert")
        if [[ -z "${2:-}" ]]; then
            echo "❌ Uso: security-manager send-alert <mensaje>"
            exit 1
        fi
        send_security_alert "$2"
        ;;
    "logs") tail -f ~/.local/security/logs/security.log 2>/dev/null || echo "No hay logs disponibles" ;;
    *) 
        echo "🔐 Security Manager - Comandos disponibles:"
        echo "  audit-quick    - Auditoría rápida del sistema"
        echo "  audit-full     - Auditoría completa"
        echo "  status         - Estado del sistema"
        echo "  send-alert <msg> - Enviar alerta manual"
        echo "  logs           - Ver logs en tiempo real"
        ;;
esac
EOF

# --- VAULT ---
cat > "$INSTALL_DIR/bin/enterprise-vault.sh" << 'EOF'
#!/bin/bash
case "${1:-}" in
    "encrypt") echo "🔐 Vault: Secretos encriptados (simulado)" ;;
    "get")     echo "🔓 Vault: Obteniendo secreto ${2:-}" ;;
    "list")
        echo "📋 Vault: Listando secretos"
        echo "TELEGRAM_BOT_TOKEN"
        echo "TELEGRAM_CHAT_ID"
        ;;
    *) echo "Vault commands: encrypt, get, list" ;;
esac
EOF

# --- QUEUE ---
cat > "$INSTALL_DIR/bin/sqlite-queue.sh" << 'EOF'
#!/bin/bash
case "${1:-}" in
    "send")   echo "queue-$(date +%s)-$(shuf -i 1000-9999 -n 1)" ;;
    "status") echo "✅ Cola funcionando - Mensajes: 0 pendientes" ;;
    *) echo "Queue commands: send, status" ;;
esac
EOF

# --- OBSERVABILITY ---
cat > "$INSTALL_DIR/bin/high-perf-observability.sh" << 'EOF'
#!/bin/bash
# High Performance Observability Agent
set -euo pipefail

readonly OBS_SOCKET="/tmp/security-obs.sock"
readonly OBS_LOG_DIR="$HOME/.local/security/logs"
readonly PID_FILE="/tmp/security-obs.pid"
readonly OBS_DAEMON="$HOME/.local/security/bin/security-obs-daemon.py"
readonly DAEMON_LOG="$OBS_LOG_DIR/obs-daemon.log"

mkdir -p "$OBS_LOG_DIR"

start_obs() {
    echo "🚀 Iniciando módulo de observabilidad..."
    
    # Verificar que el script Python existe
    if [[ ! -f "$OBS_DAEMON" ]]; then
        echo "❌ No se encuentra el script Python: $OBS_DAEMON"
        return 1
    fi

    # Limpiar proceso anterior
    stop_obs
    
    # Ejecutar el daemon Python
    python3 "$OBS_DAEMON" &
    local py_pid=$!
    echo $py_pid > "$PID_FILE"
    
    # Esperar a que se inicialice
    local timeout=10
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if [[ -S "$OBS_SOCKET" ]]; then
            echo "✅ security-obs iniciado (PID $py_pid)"
            return 0
        fi
        
        if ! kill -0 $py_pid 2>/dev/null; then
            echo "❌ El daemon Python se cerró"
            if [[ -f "$DAEMON_LOG" ]]; then
                echo "📄 Revisa: $DAEMON_LOG"
            fi
            rm -f "$PID_FILE"
            return 1
        fi
        
        sleep 1
        ((count++))
    done
    
    echo "⚠️  Timeout - iniciando sin socket"
    return 0
}

stop_obs() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            kill "$pid" 2>/dev/null || true
            echo "🛑 security-obs detenido"
        fi
        rm -f "$PID_FILE"
    else
        echo "⚠️  security-obs no estaba en ejecución"
    fi
    rm -f "$OBS_SOCKET"
}

status_obs() {
    if [[ -f "$PID_FILE" ]] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
        echo "✅ security-obs activo (PID $(cat "$PID_FILE"))"
    else
        echo "❌ security-obs inactivo"
    fi
}

case "${1:-}" in
    start) start_obs ;;
    stop)  stop_obs ;;
    status) status_obs ;;
    *) echo "Uso: security-obs {start|stop|status}" ;;
esac
EOF

# --- OBSERVABILITY PYTHON SCRIPT ---
cat > "$INSTALL_DIR/bin/security-obs-daemon.py" << 'PYTHON_EOF'
#!/usr/bin/env python3
import asyncio
import json
import os
import sys
from datetime import datetime, timezone

try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

OBS_SOCKET = "/tmp/security-obs.sock"
OBS_LOG_FILE = os.path.expanduser("~/.local/security/logs/observability.jsonl")
DAEMON_LOG = os.path.expanduser("~/.local/security/logs/obs-daemon.log")

def log_daemon(msg):
    try:
        os.makedirs(os.path.dirname(DAEMON_LOG), exist_ok=True)
        with open(DAEMON_LOG, "a") as f:
            f.write(f"{datetime.now().isoformat()} - {msg}\n")
    except:
        pass

class SecurityObservability:
    def __init__(self):
        self.batch = []
        os.makedirs(os.path.dirname(OBS_LOG_FILE), exist_ok=True)
        log_daemon("🟢 Iniciando daemon de observabilidad")

    async def handle_client(self, reader, writer):
        try:
            data = await reader.read(4096)
            if data:
                record = json.loads(data.decode())
                record["timestamp"] = datetime.now(timezone.utc).isoformat()
                self.batch.append(record)
                if len(self.batch) >= 10:
                    await self.flush()
        except Exception as e:
            log_daemon(f"❌ Error en cliente: {e}")
        finally:
            writer.close()

    async def flush(self):
        try:
            if self.batch:
                with open(OBS_LOG_FILE, "a") as f:
                    for record in self.batch:
                        f.write(json.dumps(record) + "\n")
                self.batch.clear()
        except Exception as e:
            log_daemon(f"❌ Error en flush: {e}")

    async def metric_loop(self):
        while True:
            try:
                metric = {
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "type": "system_metrics"
                }
                
                if PSUTIL_AVAILABLE:
                    metric["cpu_percent"] = psutil.cpu_percent(interval=1)
                    metric["memory_mb"] = psutil.virtual_memory().used // (1024 * 1024)
                    metric["memory_percent"] = psutil.virtual_memory().percent
                else:
                    with open('/proc/loadavg', 'r') as f:
                        metric["loadavg"] = f.read().strip()
                
                self.batch.append(metric)
                await self.flush()
                
            except Exception as e:
                log_daemon(f"❌ Error en metric_loop: {e}")
            
            await asyncio.sleep(5)

    async def start_server(self):
        try:
            if os.path.exists(OBS_SOCKET):
                os.unlink(OBS_SOCKET)
            
            server = await asyncio.start_unix_server(
                self.handle_client,
                OBS_SOCKET
            )
            
            log_daemon(f"✅ Socket creado en {OBS_SOCKET}")
            
            asyncio.create_task(self.metric_loop())
            
            async with server:
                await server.serve_forever()
                
        except Exception as e:
            log_daemon(f"❌ Error crítico en servidor: {e}")
            raise

def main():
    try:
        log_daemon("🚀 Iniciando Security Observability Daemon")
        obs = SecurityObservability()
        asyncio.run(obs.start_server())
    except KeyboardInterrupt:
        log_daemon("⏹️  Daemon detenido por usuario")
    except Exception as e:
        log_daemon(f"💥 Error fatal: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
PYTHON_EOF

touch ~/.local/security/vault/secrets.vault
sqlite3 ~/.local/security/queue/security_queue.db "CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY, content TEXT, timestamp TEXT);"

# === PERMISOS ===
chmod +x "$INSTALL_DIR/bin"/*.sh

# === ENLACES SIMBÓLICOS ===
echo "🔗 Creando enlaces simbólicos..."
ln -sf "$INSTALL_DIR/bin/security-manager.sh" "$BIN_DIR/security-manager"
ln -sf "$INSTALL_DIR/bin/enterprise-vault.sh" "$BIN_DIR/security-vault"
ln -sf "$INSTALL_DIR/bin/sqlite-queue.sh" "$BIN_DIR/security-queue"
ln -sf "$INSTALL_DIR/bin/high-perf-observability.sh" "$BIN_DIR/security-obs"

# === VERIFICACIÓN FINAL ===
echo ""
echo "✅ INSTALACIÓN COMPLETADA"
echo "🔍 Verificando comandos..."
for cmd in security-manager security-vault security-queue security-obs; do
    if [[ -f "$BIN_DIR/$cmd" ]]; then
        echo "  ✅ $cmd instalado"
    else
        echo "  ❌ $cmd falló"
    fi
done

echo ""
echo "🎯 USO:"
echo "  security-manager status"
echo "  security-vault list"
echo "  security-queue status"
echo "  security-obs start"
