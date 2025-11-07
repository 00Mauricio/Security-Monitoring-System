#!/bin/bash
# high-perf-observability.sh — Versión robusta con archivo Python
set -euo pipefail

readonly OBS_SOCKET="/tmp/security-obs.sock"
readonly OBS_LOG_DIR="$HOME/.local/security/logs"
readonly PID_FILE="/tmp/security-obs.pid"
readonly OBS_DAEMON="$HOME/.local/security/bin/security-obs-daemon.py"
readonly DAEMON_LOG="$OBS_LOG_DIR/obs-daemon.log"

mkdir -p "$OBS_LOG_DIR"

check_python_deps() {
    echo "🔍 Verificando dependencias Python..."
    
    if ! python3 -c "import asyncio" 2>/dev/null; then
        echo "❌ asyncio no disponible"
        return 1
    fi
    
    if ! python3 -c "import psutil" 2>/dev/null; then
        echo "⚠️  psutil no disponible - usando métricas básicas"
    fi
    
    echo "✅ Dependencias Python verificadas"
    return 0
}

start_obs_daemon() {
    echo "🚀 Iniciando módulo de observabilidad..."
    
    # Verificar que el script Python existe
    if [[ ! -f "$OBS_DAEMON" ]]; then
        echo "❌ No se encuentra el script Python: $OBS_DAEMON"
        return 1
    fi

    # Verificar dependencias
    check_python_deps

    # Limpiar proceso anterior
    stop_obs
    
    # Ejecutar el daemon Python directamente
    echo "🔍 Ejecutando daemon Python..."
    python3 "$OBS_DAEMON" &
    local py_pid=$!
    echo $py_pid > "$PID_FILE"
    
    # Esperar a que se inicialice
    local timeout=10
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if [[ -S "$OBS_SOCKET" ]]; then
            echo "✅ security-obs iniciado correctamente (PID $py_pid)"
            echo "📊 Socket activo: $OBS_SOCKET"
            return 0
        fi
        
        # Verificar si el proceso sigue vivo
        if ! kill -0 $py_pid 2>/dev/null; then
            echo "❌ El daemon Python se cerró inesperadamente"
            if [[ -f "$DAEMON_LOG" ]]; then
                echo "📄 Revisa los logs: $DAEMON_LOG"
                tail -5 "$DAEMON_LOG"
            fi
            rm -f "$PID_FILE"
            return 1
        fi
        
        sleep 1
        ((count++))
    done
    
    echo "⚠️  Timeout - el socket no se creó en $timeout segundos"
    if [[ -f "$DAEMON_LOG" ]]; then
        echo "📄 Últimos logs:"
        tail -5 "$DAEMON_LOG"
    fi
    return 1
}

start_basic_obs() {
    echo "🔄 Iniciando modo básico (sin Python)..."
    stop_obs
    
    nohup bash -c "
        echo '🟢 Iniciando observabilidad básica - \$(date)' > '$DAEMON_LOG'
        while true; do
            timestamp=\$(date -Iseconds)
            cpu=\$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2 + \$4}')
            mem=\$(free -m | awk '/Mem:/ {print \$3}')
            echo \"[\$timestamp] CPU: \${cpu}% MEM: \${mem}MB\" >> '$OBS_LOG_DIR/obs.log'
            sleep 5
        done
    " >/dev/null 2>&1 &
    
    echo \$! > "$PID_FILE"
    echo "✅ Observabilidad básica iniciada (PID \$(cat "$PID_FILE"))"
}

stop_obs() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=\$(cat "$PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            kill "$pid" 2>/dev/null && echo "🛑 security-obs detenido (PID $pid)"
            sleep 2
        fi
        rm -f "$PID_FILE"
    fi
    rm -f "$OBS_SOCKET"
    echo "🧹 Recursos limpiados"
}

status_obs() {
    if [[ -S "$OBS_SOCKET" ]]; then
        echo "✅ security-obs activo (socket operativo)"
        return 0
    elif [[ -f "$PID_FILE" ]] && ps -p "\$(cat "$PID_FILE")" >/dev/null 2>&1; then
        echo "⚠️  security-obs activo pero sin socket"
        return 0
    else
        echo "❌ security-obs inactivo"
        return 1
    fi
}

case "\${1:-}" in
    start) 
        if start_obs_daemon; then
            echo "🎉 Observabilidad iniciada correctamente"
        else
            echo "❌ Falló el inicio de observabilidad - intentando modo básico"
            start_basic_obs
        fi
        ;;
    stop)  stop_obs ;;
    status) status_obs ;;
    *) 
        echo "Uso: security-obs {start|stop|status}"
        echo ""
        echo "🔍 Diagnóstico:"
        echo "  Ver logs: tail -f $DAEMON_LOG"
        echo "  Ver socket: ls -la $OBS_SOCKET"
        echo "  Ver proceso: ps -p \$(cat $PID_FILE 2>/dev/null) 2>/dev/null"
        ;;
esac
