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
