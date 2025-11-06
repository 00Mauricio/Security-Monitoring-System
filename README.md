# 🔐 Enterprise Security Monitoring System

Sistema enterprise-grade para monitoreo y auditoría de seguridad con notificaciones centralizadas.

## ✨ Características

- 🔒 **Vault seguro** con AES-256-GCM y rotación automática de keys
- 📬 **Cola transaccional** con SQLite y DLQ
- 📊 **Observabilidad de alta performance** con daemon dedicado
- 🤖 **Notificaciones multi-canal** (Telegram, Discord, Webhook)
- 🛡️ **Hardening enterprise** de scripts Bash
- 🔄 **Sistema de reintentos** con backoff exponencial
- 📈 **Métricas Prometheus** integradas

## 🚀 Instalación Rápida

```bash
git clone https://github.com/tuusuario/security-monitoring-enterprise.git
cd security-monitoring-enterprise
./install.sh
```
## 📋 Requisitos
- Linux (probado en Ubuntu/Debian/CentOS)
- Bash 4.0+
- SQLite3
- OpenSSL
- Python 3.6+ (para daemon de observabilidad)

## 🛠️ Uso
```bash
# Gestión de secretos
security-vault encrypt TELEGRAM_BOT_TOKEN "your_token"
security-vault get TELEGRAM_BOT_TOKEN

# Gestión de colas
security-queue send "Mensaje de alerta"
security-queue status

# Auditorías
security-manager audit-quick
security-manager audit-full
security-manager send-alert "Alerta manual"

# Monitoreo
security-manager status
security-manager logs
```
🔧 Configuración
Configurar Telegram (opcional):
```bash
security-vault encrypt TELEGRAM_BOT_TOKEN "123:ABC"
security-vault encrypt TELEGRAM_CHAT_ID "456"
```
Configurar tareas programadas:

```bash
crontab -e
# Agregar contenido de examples/crontab.example
```
📁 Estructura
text
~/.local/security/
├── bin/          # Scripts ejecutables
├── vault/        # Secretos encriptados
├── queue/        # Base de datos SQLite
├── logs/         # Logs estructurados JSON
└── config/       # Configuración
🐛 Solución de Problemas
Ver docs/troubleshooting.md para problemas comunes.

🤝 Contribución
Las contribuciones son bienvenidas. Por favor lee CONTRIBUTING.md antes de enviar PRs.

📄 Licencia
MIT License - ver LICENSE para detalles.