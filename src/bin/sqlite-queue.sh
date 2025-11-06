#!/bin/bash
# sqlite-queue.sh
set -euo pipefail

readonly QUEUE_DB="$HOME/.local/security/queue/security_queue.db"
readonly LOCK_TIMEOUT=300  # 5 minutes

init_sqlite_queue() {
    mkdir -p "$(dirname "$QUEUE_DB")"
    
    sqlite3 "$QUEUE_DB" << 'EOF'
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending', 'processing', 'dlq')),
    priority INTEGER DEFAULT 0,
    payload TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at DATETIME NULL,
    retries INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    locked_until DATETIME NULL,
    hash TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_status_priority ON messages(status, priority, created_at);
CREATE INDEX IF NOT EXISTS idx_locked_until ON messages(locked_until);
CREATE INDEX IF NOT EXISTS idx_hash ON messages(hash);
EOF
}

queue_message_sqlite() {
    local message="$1"
    local priority="${2:-0}"
    local message_id=$(date +%s%N)-$(openssl rand -hex 4)
    local hash=$(echo -n "$message" | sha256sum | cut -d' ' -f1)
    
    sqlite3 "$QUEUE_DB" "INSERT OR IGNORE INTO messages 
        (message_id, status, priority, payload, hash) 
        VALUES ('$message_id', 'pending', $priority, '$(echo "$message" | sqlite3_escape)', '$hash');"
    echo "$message_id"
}

acquire_message() {
    local worker_id="$1"
    
    # Atomic acquisition with lock timeout
    sqlite3 "$QUEUE_DB" << EOF
UPDATE messages 
SET status = 'processing', locked_until = datetime('now', '+$LOCK_TIMEOUT seconds')
WHERE id = (
    SELECT id FROM messages 
    WHERE status = 'pending' AND (locked_until IS NULL OR locked_until < datetime('now'))
    ORDER BY priority DESC, created_at ASC 
    LIMIT 1
)
RETURNING id, message_id, payload;
EOF
}

complete_message() {
    local message_id="$1"
    sqlite3 "$QUEUE_DB" "DELETE FROM messages WHERE message_id = '$message_id';"
}

fail_message() {
    local message_id="$1"
    sqlite3 "$QUEUE_DB" << EOF
UPDATE messages 
SET retries = retries + 1,
    status = CASE WHEN retries + 1 >= max_retries THEN 'dlq' ELSE 'pending' END,
    locked_until = NULL
WHERE message_id = '$message_id';
EOF
}

# Helper para escape SQL
sqlite3_escape() {
    sed "s/'/''/g"
}

# CLI para gestión
queue_status() {
    sqlite3 -header -column "$QUEUE_DB" "
        SELECT 
            status,
            COUNT(*) as count,
            MAX(created_at) as latest,
            AVG((julianday('now') - julianday(created_at)) * 86400) as avg_age_seconds
        FROM messages 
        GROUP BY status;"
}