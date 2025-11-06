#!/bin/bash
# enterprise-vault.sh
set -euo pipefail
IFS=$'\n\t'

readonly VAULT_DIR="$HOME/.local/security/vault"
readonly VAULT_FILE="$VAULT_DIR/secrets.vault"
readonly KEY_DIR="$VAULT_DIR/keys"
readonly CURRENT_KEY_FILE="$KEY_DIR/current.key"
readonly KEY_VERSION=$(date +%Y%m)

init_enterprise_vault() {
    mkdir -p "$VAULT_DIR" "$KEY_DIR"
    chmod 700 "$VAULT_DIR" "$KEY_DIR"
    
    # Rotación mensual automática de keys
    if [[ ! -f "$CURRENT_KEY_FILE" ]] || [[ "$(basename $(readlink "$CURRENT_KEY_FILE"))" != "$KEY_VERSION.key" ]]; then
        local new_key="$KEY_DIR/${KEY_VERSION}.key"
        openssl rand -base64 32 > "$new_key"
        chmod 600 "$new_key"
        ln -sf "$new_key" "$CURRENT_KEY_FILE"
        
        # Re-encriptar todos los secrets con nueva key
        reencrypt_vault
    fi
}

reencrypt_vault() {
    [[ ! -f "$VAULT_FILE" ]] && return 0
    
    local temp_file=$(mktemp "$VAULT_DIR/.reencrypt.XXXXXX")
    chmod 600 "$temp_file"
    
    # Desencriptar con keys antiguas y re-encriptar con nueva
    for key_file in "$KEY_DIR"/*.key; do
        [[ -f "$key_file" ]] || continue
        if openssl enc -aes-256-gcm -d -pbkdf2 -pass "file:$key_file" -in "$VAULT_FILE" -out "$temp_file" 2>/dev/null; then
            local hmac=$(openssl dgst -sha256 -hmac "$(cat "$key_file")" "$temp_file" | cut -d' ' -f2)
            openssl enc -aes-256-gcm -e -pbkdf2 -pass "file:$CURRENT_KEY_FILE" -in "$temp_file" -out "$VAULT_FILE.new"
            echo "$hmac" > "$VAULT_FILE.hmac"
            mv "$VAULT_FILE.new" "$VAULT_FILE"
            break
        fi
    done
    
    # Limpieza segura
    shred -u "$temp_file" 2>/dev/null || rm -P "$temp_file"
}

encrypt_secret_enterprise() {
    local key="$1"
    local value="$2"
    init_enterprise_vault
    
    # Cargar secrets existentes de forma atómica
    local temp_file=$(mktemp "$VAULT_DIR/.update.XXXXXX")
    chmod 600 "$temp_file"
    
    if [[ -f "$VAULT_FILE" ]]; then
        local current_key=$(readlink -f "$CURRENT_KEY_FILE")
        if ! openssl enc -aes-256-gcm -d -pbkdf2 -pass "file:$current_key" -in "$VAULT_FILE" -out "$temp_file" 2>/dev/null; then
            shred -u "$temp_file"
            log_structured "ERROR" "Failed to decrypt vault" "{\"operation\": \"encrypt_secret\"}"
            return 1
        fi
    fi
    
    # Actualizar valor usando jq para manipulación segura
    if [[ -s "$temp_file" ]]; then
        jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$temp_file" > "${temp_file}.new"
    else
        jq -n --arg k "$key" --arg v "$value" '.[$k] = $v' > "${temp_file}.new"
    fi
    
    # Encriptar con AES-GCM
    openssl enc -aes-256-gcm -e -pbkdf2 -pass "file:$CURRENT_KEY_FILE" \
        -in "${temp_file}.new" -out "${VAULT_FILE}.atomic"
    
    # Verificar integridad
    local hmac=$(openssl dgst -sha256 -hmac "$(cat "$CURRENT_KEY_FILE")" "${temp_file}.new" | cut -d' ' -f2)
    
    # Commit atómico
    mv "${VAULT_FILE}.atomic" "$VAULT_FILE"
    echo "$hmac" > "$VAULT_FILE.hmac"
    
    # Limpieza segura
    shred -u "$temp_file" "${temp_file}.new"
}

get_secret_enterprise() {
    local key="$1"
    init_enterprise_vault
    
    [[ ! -f "$VAULT_FILE" ]] && return 1
    
    local temp_file=$(mktemp "$VAULT_DIR/.read.XXXXXX")
    chmod 600 "$temp_file"
    
    local current_key=$(readlink -f "$CURRENT_KEY_FILE")
    if openssl enc -aes-256-gcm -d -pbkdf2 -pass "file:$current_key" -in "$VAULT_FILE" -out "$temp_file" 2>/dev/null; then
        # Verificar HMAC
        local expected_hmac=$(cat "$VAULT_FILE.hmac" 2>/dev/null || echo "")
        local actual_hmac=$(openssl dgst -sha256 -hmac "$(cat "$current_key")" "$temp_file" | cut -d' ' -f2)
        
        if [[ "$expected_hmac" != "$actual_hmac" ]]; then
            shred -u "$temp_file"
            log_structured "ERROR" "Vault integrity check failed" "{\"operation\": \"get_secret\"}"
            return 1
        fi
        
        jq -r --arg k "$key" '.[$k] // empty' "$temp_file"
        local result=$?
        shred -u "$temp_file"
        return $result
    else
        shred -u "$temp_file"
        return 1
    fi
}