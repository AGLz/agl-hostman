#!/bin/bash
# GPG Backup Key Setup Script
# Purpose: Generate and configure GPG keys for encrypted backup replication
#
# Usage:
#   ./setup-gpg-backup-keys.sh                    # Interactive mode
#   ./setup-gpg-backup-keys.sh --batch            # Non-interactive mode
#   ./setup-gpg-backup-keys.sh --export           # Export existing keys
#   ./setup-gpg-backup-keys.sh --restore KEYFILE  # Import keys from file

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/replication-config.env"
KEY_EXPORT_DIR="${SCRIPT_DIR}/gpg-keys"
KEY_BACKUP_FILE="agl-backup-gpg-keys-$(date +%Y%m%d).tar.gz.gpg"

# Default key configuration
KEY_NAME_REAL="AGL Backup System"
KEY_NAME_COMMENT="Automated backup encryption"
KEY_NAME_EMAIL="agl-backup@local"
KEY_EXPIRY="0"  # 0 = no expiration
KEY_TYPE="RSA"
KEY_LENGTH="4096"
KEY_PASSPHHRASE=""  # Empty for automated backups (use proper key security instead)

# ============================================================================
# COLORS AND OUTPUT
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_gpg() {
    if ! command -v gpg >/dev/null 2>&1; then
        log_error "GPG is not installed"
        log_info "Install with: apt-get install gnupg"
        exit 1
    fi
}

load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${CONFIG_FILE}"
        log_info "Loaded configuration from ${CONFIG_FILE}"
    fi
}

create_key_directory() {
    mkdir -p "${KEY_EXPORT_DIR}"
    chmod 700 "${KEY_EXPORT_DIR}"
}

# ============================================================================
# KEY GENERATION FUNCTIONS
# ============================================================================

generate_batch_key() {
    log_info "Generating GPG key in batch mode..."

    local key_params
    key_params=$(cat <<EOF
%no-protection
Key-Type: ${KEY_TYPE}
Key-Length: ${KEY_LENGTH}
Subkey-Type: ${KEY_TYPE}
Subkey-Length: ${KEY_LENGTH}
Name-Real: ${KEY_NAME_REAL}
Name-Comment: ${KEY_NAME_COMMENT}
Name-Email: ${KEY_NAME_EMAIL}
Expire-Date: ${KEY_EXPIRY}
%commit
EOF
)

    if echo "${key_params}" | gpg --batch --generate-key; then
        log_success "GPG key generated successfully"
        return 0
    else
        log_error "Failed to generate GPG key"
        return 1
    fi
}

generate_interactive_key() {
    log_info "Generating GPG key in interactive mode..."
    log_info "Please provide the following information:"
    log_warn "Important: Use a strong passphrase if prompted"

    if gpg --full-generate-key; then
        log_success "GPG key generated successfully"
        return 0
    else
        log_error "Failed to generate GPG key"
        return 1
    fi
}

# ============================================================================
# KEY EXPORT FUNCTIONS
# ============================================================================

export_keys() {
    log_info "Exporting GPG keys..."

    create_key_directory

    # Find the key ID
    local key_id
    key_id=$(gpg --list-keys "${KEY_NAME_EMAIL}" 2>/dev/null | grep -m1 -oP '(?<=pub\s)[A-F0-9]+' || true)

    if [[ -z "${key_id}" ]]; then
        # Try to get first available key
        key_id=$(gpg --list-keys --with-colons 2>/dev/null | grep -m1 '^fpr' | cut -d: -f10 || true)
    fi

    if [[ -z "${key_id}" ]]; then
        log_error "No GPG key found for export"
        return 1
    fi

    log_info "Found key ID: ${key_id}"

    # Export public key
    local public_key_file="${KEY_EXPORT_DIR}/public-key.asc"
    if gpg --armor --export "${key_id}" > "${public_key_file}"; then
        log_success "Public key exported: ${public_key_file}"
    else
        log_error "Failed to export public key"
        return 1
    fi

    # Export private key
    local private_key_file="${KEY_EXPORT_DIR}/private-key.asc"
    if gpg --armor --export-secret-keys "${key_id}" > "${private_key_file}"; then
        log_success "Private key exported: ${private_key_file}"
    else
        log_error "Failed to export private key"
        return 1
    fi

    # Export owner trust
    local trust_file="${KEY_EXPORT_DIR}/ownertrust.txt"
    if gpg --export-ownertrust > "${trust_file}"; then
        log_success "Owner trust exported: ${trust_file}"
    fi

    # Create revocation certificate
    local revoke_file="${KEY_EXPORT_DIR}/revocation-cert.asc"
    if gpg --armor --gen-revoke "${key_id}" > "${revoke_file}"; then
        log_success "Revocation certificate created: ${revoke_file}"
        log_warn "Store the revocation certificate in a secure, separate location"
    fi

    # Display key information
    display_key_info "${key_id}"

    return 0
}

display_key_info() {
    local key_id="$1"

    echo ""
    echo "=========================================="
    echo "GPG Key Information"
    echo "=========================================="
    gpg --list-keys "${key_id}"
    echo ""
    echo "Key ID: ${key_id}"
    echo "Email: ${KEY_NAME_EMAIL}"
    echo "=========================================="
    echo ""
}

create_encrypted_backup() {
    log_info "Creating encrypted backup of GPG keys..."

    local backup_file="${KEY_EXPORT_DIR}/${KEY_BACKUP_FILE}"

    if tar czf - "${KEY_EXPORT_DIR}"/*.asc "${KEY_EXPORT_DIR}"/*.txt 2>/dev/null | \
        gpg --armor --symmetric --cipher-algo AES256 --output "${backup_file}"; then
        log_success "Encrypted key backup created: ${backup_file}"
        log_info "Backup file size: $(du -h "${backup_file}" | cut -f1)"
        log_warn "IMPORTANT: Store this backup in a secure, offsite location"
        log_info "You will need the passphrase to decrypt this backup"
        return 0
    else
        log_error "Failed to create encrypted backup"
        return 1
    fi
}

# ============================================================================
# KEY IMPORT FUNCTIONS
# ============================================================================

import_keys() {
    local key_file="$1"

    if [[ ! -f "${key_file}" ]]; then
        log_error "Key file not found: ${key_file}"
        return 1
    fi

    log_info "Importing GPG keys from: ${key_file}"

    # Decrypt if encrypted
    local temp_dir="${KEY_EXPORT_DIR}/temp-import"
    mkdir -p "${temp_dir}"

    if [[ "${key_file}" == *.gpg ]]; then
        log_info "Decrypting key backup..."
        if ! gpg --decrypt "${key_file}" | tar xzf - -C "${temp_dir}"; then
            log_error "Failed to decrypt key backup"
            return 1
        fi

        # Import all keys from temp directory
        local key_imported=false
        for key_file in "${temp_dir}"/*.asc; do
            if gpg --import "${key_file}"; then
                key_imported=true
            fi
        done

        # Import owner trust
        if [[ -f "${temp_dir}/ownertrust.txt" ]]; then
            gpg --import-ownertrust "${temp_dir}/ownertrust.txt"
        fi

        rm -rf "${temp_dir}"
    else
        # Direct import
        if gpg --import "${key_file}"; then
            key_imported=true
        fi
    fi

    if [[ "${key_imported}" == "true" ]]; then
        log_success "GPG keys imported successfully"
        return 0
    else
        log_error "Failed to import GPG keys"
        return 1
    fi
}

# ============================================================================
# CONFIGURATION UPDATE FUNCTIONS
# ============================================================================

update_config_file() {
    local key_id="$1"

    log_info "Updating configuration file..."

    if [[ -f "${CONFIG_FILE}" ]]; then
        # Update existing config
        if grep -q "ENCRYPT_GPG_KEY_ID=" "${CONFIG_FILE}"; then
            sed -i "s/^ENCRYPT_GPG_KEY_ID=.*/ENCRYPT_GPG_KEY_ID=\"${key_id}\"/" "${CONFIG_FILE}"
        else
            echo "ENCRYPT_GPG_KEY_ID=\"${key_id}\"" >> "${CONFIG_FILE}"
        fi
        log_success "Configuration file updated"
    else
        log_warn "Configuration file not found: ${CONFIG_FILE}"
        log_info "Add this line to your configuration:"
        echo "ENCRYPT_GPG_KEY_ID=\"${key_id}\""
    fi
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_key() {
    local key_id="${1:-}"

    if [[ -z "${key_id}" ]]; then
        key_id=$(gpg --list-keys --with-colons 2>/dev/null | grep -m1 '^fpr' | cut -d: -f10 || true)
    fi

    if [[ -z "${key_id}" ]]; then
        log_error "No GPG key found"
        return 1
    fi

    log_info "Validating GPG key: ${key_id}"

    # Check if key exists
    if gpg --list-keys "${key_id}" >/dev/null 2>&1; then
        log_success "Public key found"
    else
        log_error "Public key not found"
        return 1
    fi

    # Check if secret key exists
    if gpg --list-secret-keys "${key_id}" >/dev/null 2>&1; then
        log_success "Private key found"
    else
        log_warn "Private key not found (may be on different system)"
    fi

    # Test encryption/decryption
    local test_file="/tmp/gpg-test-$$"
    local test_content="GPG test at $(date)"

    echo "${test_content}" > "${test_file}"

    if gpg --batch --yes --output "${test_file}.gpg" \
        --encrypt --recipient "${KEY_NAME_EMAIL}" "${test_file}" 2>/dev/null; then
        log_success "Encryption test passed"

        if gpg --batch --yes --output "${test_file}.dec" \
            --decrypt "${test_file}.gpg" 2>/dev/null; then
            if grep -q "${test_content}" "${test_file}.dec"; then
                log_success "Decryption test passed"
                rm -f "${test_file}" "${test_file}.gpg" "${test_file}.dec"
                return 0
            else
                log_error "Decryption test failed - content mismatch"
                return 1
            fi
        else
            log_error "Decryption test failed"
            return 1
        fi
    else
        log_error "Encryption test failed"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_usage() {
    cat << EOF
GPG Backup Key Setup Script

Usage: $0 [OPTIONS] [ARGUMENTS]

Options:
    --batch              Generate key in batch mode (non-interactive)
    --export             Export existing GPG keys
    --backup             Create encrypted backup of exported keys
    --restore KEYFILE    Import keys from file
    --validate KEYID     Validate GPG key functionality
    -h, --help           Show this help message

Examples:
    $0                              # Interactive key generation
    $0 --batch                      # Generate key without prompts
    $0 --export --backup            # Export and backup keys
    $0 --restore backup.tar.gz.gpg  # Restore keys from backup
    $0 --validate ABCD1234          # Validate specific key

Configuration file: ${CONFIG_FILE}
Key export directory: ${KEY_EXPORT_DIR}

Security Notes:
    - Store the private key and revocation certificate in secure, separate locations
    - The encrypted backup contains both public and private keys
    - Keep the backup passphrase safe and separate from the backup file
    - Consider using a hardware security module (HSM) for production use
EOF
}

main() {
    local batch_mode=false
    local export_only=false
    local create_backup=false
    local restore_file=""
    local validate_key_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --batch)
                batch_mode=true
                shift
                ;;
            --export)
                export_only=true
                shift
                ;;
            --backup)
                create_backup=true
                shift
                ;;
            --restore)
                restore_file="$2"
                shift 2
                ;;
            --validate)
                validate_key_id="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Initialization
    check_root
    check_gpg
    load_config

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  GPG Backup Key Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Restore mode
    if [[ -n "${restore_file}" ]]; then
        import_keys "${restore_file}"
        exit $?
    fi

    # Validate mode
    if [[ -n "${validate_key_id}" ]]; then
        validate_key "${validate_key_id}"
        exit $?
    fi

    # Export mode
    if [[ "${export_only}" == "true" ]]; then
        export_keys

        if [[ "${create_backup}" == "true" ]]; then
            create_encrypted_backup
        fi

        exit 0
    fi

    # Key generation mode
    local key_id=""
    if [[ "${batch_mode}" == "true" ]]; then
        generate_batch_key
    else
        generate_interactive_key
    fi

    # Get the key ID
    key_id=$(gpg --list-keys "${KEY_NAME_EMAIL}" 2>/dev/null | grep -m1 -oP '(?<=pub\s)[A-F0-9]+' || true)

    if [[ -z "${key_id}" ]]; then
        key_id=$(gpg --list-keys --with-colons 2>/dev/null | grep -m1 '^fpr' | cut -d: -f10 || true)
    fi

    if [[ -n "${key_id}" ]]; then
        display_key_info "${key_id}"
        update_config_file "${key_id}"
        export_keys

        if [[ "${create_backup}" == "true" ]]; then
            create_encrypted_backup
        fi

        # Validate the key
        validate_key "${key_id}"

        echo ""
        log_success "GPG key setup completed successfully"
        log_info "Key ID: ${key_id}"
        log_info "Key files exported to: ${KEY_EXPORT_DIR}"
        log_warn "IMPORTANT: Store the exported keys in secure, offsite locations"
        log_warn "Keep the revocation certificate separate and secure"
    else
        log_error "Failed to locate generated key"
        exit 1
    fi
}

main "$@"
