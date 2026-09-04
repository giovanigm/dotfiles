#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# NixOS Dotfiles Installer
# Post-install configuration for impermanence-based NixOS
# with Hyprland + NVIDIA RTX 3080
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_VERSION="1.0.0"
REPO_URL="https://github.com/giovani/dotfiles.git"
REQUIRED_NIXOS_VERSION="26.05"

# ── Paths ──────────────────────────────────────────────────
REPO_DIR="${HOME}/dev/dotfiles"
NIXOS_DIR="${REPO_DIR}/nixos"
PERSIST_DIR="/persist"
PASSWORD_FILE="${PERSIST_DIR}/passwords/giovani"
USERNAME="giovani"

# ── Colors ─────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ── Flags ──────────────────────────────────────────────────
AUTO_YES=false
DRY_RUN=false
SKIP_REBUILD=false

# ═══════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}${BOLD}── $* ──${NC}"; }

run() {
    if $DRY_RUN; then
        echo -e "       ${YELLOW}[DRY-RUN]${NC} $*"
    else
        "$@"
    fi
}

run_sudo() {
    if $DRY_RUN; then
        echo -e "       ${YELLOW}[DRY-RUN]${NC} sudo $*"
    else
        sudo "$@"
    fi
}

confirm() {
    if $AUTO_YES; then
        info "Auto-confirming: ${1:-Continue?}"
        return 0
    fi
    local prompt="${1:-Continue?}"
    read -r -p "       ${prompt} [y/N] " response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

confirm_or_skip() {
    if confirm "${1:-Skip this step?}"; then
        return 0   # user said yes → proceed
    else
        warn "Skipping: ${1:-step}"
        return 1   # user said no → skip
    fi
}

read_silent() {
    local prompt="$1"
    local var_name="$2"
    local value
    read -r -s -p "       ${prompt}: " value
    echo ""
    printf -v "$var_name" '%s' "$value"
}

# ═══════════════════════════════════════════════════════════
# PHASE 0 — BOOTSTRAP (curl-pipe mode)
# ═══════════════════════════════════════════════════════════

bootstrap_from_curl() {
    # If we're already inside the repo, skip bootstrap
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "${script_dir}/nixos" ] && [ -f "${script_dir}/Makefile" ]; then
        return 0
    fi

    step "Phase 0 — Bootstrap"
    info "Detected standalone run (curl-pipe or direct download)."
    info "Will clone the dotfiles repo and re-execute from there."

    if [ -d "$REPO_DIR/.git" ]; then
        ok "Repo already exists at $REPO_DIR, pulling latest..."
        run git -C "$REPO_DIR" pull
    elif [ -d "$REPO_DIR" ]; then
        error "$REPO_DIR exists but is not a git clone of this repo.
       Please move it aside and re-run."
    else
        info "Cloning $REPO_URL → $REPO_DIR"
        run mkdir -p "$(dirname "$REPO_DIR")"
        run git clone "$REPO_URL" "$REPO_DIR"
    fi

    ok "Re-executing from $REPO_DIR/install.sh"
    exec "$REPO_DIR/install.sh" "$@"
}

# ═══════════════════════════════════════════════════════════
# PHASE 1 — PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════

check_nixos() {
    step "Phase 1 — Pre-flight checks"

    info "Checking OS..."
    if [ ! -f /etc/os-release ]; then
        error "/etc/os-release not found — not a NixOS system."
    fi
    if ! grep -q '^ID=nixos' /etc/os-release; then
        error "This script only runs on NixOS.
       Boot a NixOS system first (ISO or installed)."
    fi
    ok "Running on NixOS"
}

check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        error "Do not run this script as root.
       Run as your normal user (sudo will be used where needed)."
    fi
    ok "Running as normal user ($USER)"
}

check_sudo() {
    if ! command -v sudo &>/dev/null; then
        error "sudo is not installed."
    fi
    # Non-blocking check — just warn if passwordless sudo isn't set up
    if ! sudo -n true &>/dev/null 2>&1; then
        warn "sudo requires a password (you'll be prompted when needed)."
    else
        ok "sudo available (passwordless)"
    fi
}

check_internet() {
    info "Checking internet connectivity..."
    local all_ok=true
    for host in nixos.org github.com cache.nixos.org; do
        if ! curl -s --max-time 5 "https://${host}/" >/dev/null 2>&1; then
            warn "Cannot reach ${host}"
            all_ok=false
        fi
    done
    if ! $all_ok; then
        warn "Some hosts are unreachable. nixos-rebuild may fail."
        confirm_or_skip "Continue despite network issues?" || exit 1
    else
        ok "Internet connectivity OK"
    fi
}

check_nixos_version() {
    info "Checking NixOS version..."
    local current
    current="$(nixos-version 2>/dev/null | cut -d. -f1,2)"
    if [ -z "$current" ]; then
        warn "Could not determine NixOS version (nixos-version not found)."
        confirm_or_skip "Continue without version check?" || exit 1
    elif [ "$current" != "$REQUIRED_NIXOS_VERSION" ]; then
        warn "Running NixOS ${current}, but flake targets ${REQUIRED_NIXOS_VERSION}."
        confirm_or_skip "Continue with version mismatch?" || exit 1
    else
        ok "NixOS ${current} → matches flake (${REQUIRED_NIXOS_VERSION})"
    fi
}

check_dependencies() {
    info "Checking essential tools..."
    local missing=()
    for dep in nix git curl; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done

    # Password hash tool
    if command -v mkpasswd &>/dev/null; then
        ok "Password hash: mkpasswd available"
    elif command -v openssl &>/dev/null; then
        ok "Password hash: openssl (fallback)"
    else
        warn "Neither mkpasswd nor openssl found. Will install mkpasswd via nix."
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}
       Install them with: nix shell nixpkgs#${missing[*]} -c ..."
    fi
    ok "Essential tools: OK"
}

check_persist() {
    info "Checking /persist..."
    if [ ! -d "$PERSIST_DIR" ]; then
        error "/persist does not exist.
       This system is not set up with impermanence.
       Ensure the persist partition is mounted at /persist."
    fi
    # Note: /persist is typically root-owned. Actual write ops
    # use sudo and will fail with clear messages if permissions are wrong.
    ok "/persist exists"
}

run_preflight() {
    check_nixos
    check_not_root
    check_sudo
    check_internet
    check_nixos_version
    check_dependencies
    check_persist
}

# ═══════════════════════════════════════════════════════════
# PHASE 2 — PARTITION DISCOVERY AND LABELING
# ═══════════════════════════════════════════════════════════

detect_partitions() {
    step "Phase 2 — Partition discovery and labeling"

    echo ""
    info "Available block devices:"
    echo ""
    if command -v lsblk &>/dev/null; then
        lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINT 2>/dev/null | head -40
    else
        warn "lsblk not available, using blkid"
        blkid 2>/dev/null || warn "Cannot list partitions."
    fi
    echo ""
}

identify_candidates() {
    # Find vfat partition for /boot (ESP) — prefer one already mounted at /boot
    BOOT_DEV=""
    BOOT_UUID=""
    local mounted_boot
    mounted_boot=$(findmnt -n -o SOURCE /boot 2>/dev/null || true)
    if [ -n "$mounted_boot" ]; then
        BOOT_DEV="$mounted_boot"
        BOOT_UUID=$(lsblk -no UUID "$BOOT_DEV" 2>/dev/null || true)
    else
        # Find first vfat partition not already used
        while IFS= read -r line; do
            local dev
            dev="/dev/$(echo "$line" | awk '{print $1}')"
            if [ -b "$dev" ]; then
                BOOT_DEV="$dev"
                BOOT_UUID=$(lsblk -no UUID "$dev" 2>/dev/null || true)
                break
            fi
        done < <(lsblk -lno NAME,FSTYPE 2>/dev/null | grep -i vfat || true)
    fi

    # Find ext4 partition for /persist — prefer one already mounted at /persist
    PERSIST_DEV=""
    PERSIST_UUID=""
    local mounted_persist
    mounted_persist=$(findmnt -n -o SOURCE /persist 2>/dev/null || true)
    if [ -n "$mounted_persist" ]; then
        PERSIST_DEV="$mounted_persist"
        PERSIST_UUID=$(lsblk -no UUID "$PERSIST_DEV" 2>/dev/null || true)
    else
        # Find first ext4 partition
        while IFS= read -r line; do
            local dev
            dev="/dev/$(echo "$line" | awk '{print $1}')"
            if [ -b "$dev" ] && [ "$dev" != "$BOOT_DEV" ]; then
                PERSIST_DEV="$dev"
                PERSIST_UUID=$(lsblk -no UUID "$dev" 2>/dev/null || true)
                break
            fi
        done < <(lsblk -lno NAME,FSTYPE 2>/dev/null | grep -i ext4 || true)
    fi

    # Find Windows ESP (vfat with Microsoft boot files, not already /boot)
    WINDOWS_DEV=""
    WINDOWS_PARTUUID=""
    WINDOWS_UUID=""
    while IFS= read -r line; do
        local dev
        dev="/dev/$(echo "$line" | awk '{print $1}')"
        if [ -b "$dev" ] && [ "$dev" != "$BOOT_DEV" ]; then
            local puuid
            puuid=$(lsblk -no PARTUUID "$dev" 2>/dev/null || true)
            if [ -n "$puuid" ]; then
                # Check for Microsoft boot files (requires sudo, skip check in dry-run)
                if $DRY_RUN || (sudo mount -o ro "$dev" /tmp 2>/dev/null && [ -d /tmp/EFI/Microsoft ]); then
                    WINDOWS_DEV="$dev"
                    WINDOWS_PARTUUID="$puuid"
                    WINDOWS_UUID=$(lsblk -no UUID "$dev" 2>/dev/null || true)
                    WINDOWS_UUID="${WINDOWS_UUID^^}" # vfat UUIDs are uppercase in boot.nix
                fi
                sudo umount /tmp 2>/dev/null || true
                if [ -n "$WINDOWS_DEV" ]; then
                    break
                fi
            fi
        fi
    done < <(lsblk -lno NAME,FSTYPE 2>/dev/null | grep -i vfat || true)
}

show_mapping() {
    echo ""
    info "Detected partition layout:"
    echo ""
    printf "       %-20s %-6s %-8s → %s\n" "DEVICE" "FS" "SIZE" "ROLE"
    printf "       %-20s %-6s %-8s → %s\n" "──────" "──" "────" "────"
    if [ -n "$BOOT_DEV" ]; then
        local boot_size
        boot_size=$(lsblk -no SIZE "$BOOT_DEV" 2>/dev/null || echo "?")
        printf "       ${GREEN}%-20s${NC} %-6s %-8s → %s\n" \
            "$BOOT_DEV" "vfat" "$boot_size" "/boot (ESP)  label: nixos-boot"
    fi
    if [ -n "$PERSIST_DEV" ]; then
        local persist_size
        persist_size=$(lsblk -no SIZE "$PERSIST_DEV" 2>/dev/null || echo "?")
        printf "       ${GREEN}%-20s${NC} %-6s %-8s → %s\n" \
            "$PERSIST_DEV" "ext4" "$persist_size" "/persist     label: nixos-persist"
    fi
    if [ -n "$WINDOWS_DEV" ]; then
        local win_size
        win_size=$(lsblk -no SIZE "$WINDOWS_DEV" 2>/dev/null || echo "?")
        printf "       ${YELLOW}%-20s${NC} %-6s %-8s → %s\n" \
            "$WINDOWS_DEV" "vfat" "$win_size" "Windows ESP (dual-boot, unchanged)"
    fi
    echo ""

    if [ -z "$BOOT_DEV" ] && [ -z "$PERSIST_DEV" ]; then
        error "Could not detect any suitable partitions.
       Make sure your disks are partitioned with:
         - A vfat ESP for /boot
         - An ext4 partition for /persist"
    fi
}

apply_labels() {
    info "Applying filesystem labels..."

    if [ -n "$BOOT_DEV" ]; then
        local current_label
        current_label=$(blkid -s LABEL -o value "$BOOT_DEV" 2>/dev/null || echo "")
        if [ "$current_label" = "nixos-boot" ]; then
            ok "Label 'nixos-boot' already set on $BOOT_DEV"
        else
            info "Labeling $BOOT_DEV → nixos-boot"
            run_sudo fatlabel "$BOOT_DEV" "nixos-boot"
            ok "$BOOT_DEV labeled 'nixos-boot'"
        fi
    fi

    if [ -n "$PERSIST_DEV" ]; then
        local current_label
        current_label=$(blkid -s LABEL -o value "$PERSIST_DEV" 2>/dev/null || echo "")
        if [ "$current_label" = "nixos-persist" ]; then
            ok "Label 'nixos-persist' already set on $PERSIST_DEV"
        else
            info "Labeling $PERSIST_DEV → nixos-persist"
            run_sudo e2label "$PERSIST_DEV" "nixos-persist"
            ok "$PERSIST_DEV labeled 'nixos-persist'"
        fi
    fi
}

update_hardware_config_uuids() {
    local hw_config="${NIXOS_DIR}/hardware-configuration.nix"

    info "Checking hardware-configuration.nix UUIDs..."

    if [ -z "$BOOT_UUID" ] && [ -z "$PERSIST_UUID" ]; then
        warn "No UUIDs detected — skipping hardware-configuration.nix update."
        return 0
    fi

    local changed=false

    # Patch persist UUID
    if [ -n "$PERSIST_UUID" ]; then
        local current_persist_uuid
        current_persist_uuid=$(grep -oP 'by-uuid/\K[a-f0-9-]+' "$hw_config" | head -1 || true)
        if [ -n "$current_persist_uuid" ] && [ "$current_persist_uuid" != "$PERSIST_UUID" ]; then
            info "Persist UUID: $current_persist_uuid → $PERSIST_UUID"
            run_sudo sed -i "s|${current_persist_uuid}|${PERSIST_UUID}|g" "$hw_config"
            changed=true
        elif [ -z "$current_persist_uuid" ]; then
            warn "Could not parse persist UUID from hardware-configuration.nix."
        else
            ok "Persist UUID matches hardware."
        fi
    fi

    # Patch boot UUID
    if [ -n "$BOOT_UUID" ]; then
        local current_boot_uuid
        current_boot_uuid=$(grep -oP 'by-uuid/\K[A-F0-9-]+' "$hw_config" | tail -1 || true)
        if [ -n "$current_boot_uuid" ] && [ "$current_boot_uuid" != "$BOOT_UUID" ]; then
            info "Boot UUID: $current_boot_uuid → $BOOT_UUID"
            run_sudo sed -i "s|${current_boot_uuid}|${BOOT_UUID}|g" "$hw_config"
            changed=true
        elif [ -z "$current_boot_uuid" ]; then
            warn "Could not parse boot UUID from hardware-configuration.nix."
        else
            ok "Boot UUID matches hardware."
        fi
    fi

    # Patch Windows ESP fs-uuid in boot.nix (GRUB chainload entry) if Windows found
    if [ -n "$WINDOWS_UUID" ]; then
        local cfg="${NIXOS_DIR}/configurations/boot.nix"
        local current_win_uuid
        current_win_uuid=$(grep -oPe '--fs-uuid\s+\K[A-F0-9]{4}-[A-F0-9]{4}' "$cfg" | head -1 || true)
        if [ -n "$current_win_uuid" ] && [ "$current_win_uuid" != "$WINDOWS_UUID" ]; then
            info "Windows ESP UUID: $current_win_uuid → $WINDOWS_UUID"
            run_sudo sed -i "s|${current_win_uuid}|${WINDOWS_UUID}|g" "$cfg"
            changed=true
        elif [ -z "$current_win_uuid" ]; then
            warn "Could not parse Windows fs-uuid from boot.nix."
        else
            ok "Windows ESP UUID matches hardware."
        fi
    fi

    if $changed; then
        ok "Updated UUIDs in NixOS configuration files"
    fi
}

run_partition_setup() {
    detect_partitions
    identify_candidates
    show_mapping

    if ! confirm "Does this partition layout look correct?"; then
        echo ""
        info "Please specify partitions manually:"
        read -r -p "       Device for /boot (ESP, vfat): " BOOT_DEV
        read -r -p "       Device for /persist (ext4):   " PERSIST_DEV

        if [ -n "$BOOT_DEV" ]; then
            BOOT_UUID=$(blkid -s UUID -o value "$BOOT_DEV" 2>/dev/null || true)
        fi
        if [ -n "$PERSIST_DEV" ]; then
            PERSIST_UUID=$(blkid -s UUID -o value "$PERSIST_DEV" 2>/dev/null || true)
        fi

        echo ""
        info "Using:"
        [ -n "$BOOT_DEV" ]    && echo "       /boot:    $BOOT_DEV (UUID: ${BOOT_UUID:-unknown})"
        [ -n "$PERSIST_DEV" ] && echo "       /persist: $PERSIST_DEV (UUID: ${PERSIST_UUID:-unknown})"
        echo ""

        if ! confirm "Proceed with these devices?"; then
            error "Aborted by user."
        fi
    fi

    apply_labels
    update_hardware_config_uuids
}

# ═══════════════════════════════════════════════════════════
# PHASE 3 — HARDWARE VALIDATION
# ═══════════════════════════════════════════════════════════

check_gpu() {
    info "Checking GPU..."
    if lspci 2>/dev/null | grep -qi 'vga\|3d\|display' | grep -qi nvidia || lspci 2>/dev/null | grep -qi nvidia; then
        ok "NVIDIA GPU detected → driver config will apply"
    else
        warn "No NVIDIA GPU detected. The NVIDIA driver config in configuration.nix
         may cause issues. Consider commenting out hardware.nvidia and videoDrivers."
    fi
}

check_cpu() {
    info "Checking CPU..."
    if lscpu 2>/dev/null | grep -qi amd; then
        ok "AMD CPU detected → kvm-amd module OK"
    else
        warn "Not an AMD CPU. The kvm-amd kernel module in hardware-configuration.nix
         will fail to load. Edit boot.kernelModules to match your CPU."
    fi
}

check_nvme() {
    info "Checking storage..."
    if lsblk -d -o NAME,ROTA 2>/dev/null | grep -q nvme; then
        ok "NVMe storage detected"
    else
        warn "No NVMe storage detected. Update boot.initrd.availableKernelModules
         in hardware-configuration.nix if needed."
    fi
}

run_hardware_validation() {
    step "Phase 3 — Hardware validation"
    check_gpu
    check_cpu
    check_nvme
}

# ═══════════════════════════════════════════════════════════
# PHASE 4 — PASSWORD SETUP
# ═══════════════════════════════════════════════════════════

hash_password() {
    local pass="$1"
    local hash

    if command -v mkpasswd &>/dev/null; then
        hash=$(echo "$pass" | mkpasswd -m sha-512 -s 2>/dev/null) || true
    fi

    if [ -z "$hash" ] && command -v openssl &>/dev/null; then
        hash=$(echo "$pass" | openssl passwd -6 -stdin 2>/dev/null) || true
    fi

    if [ -z "$hash" ]; then
        # Last resort: use nix to get mkpasswd
        if command -v nix &>/dev/null; then
            info "Using nix to get mkpasswd..."
            hash=$(echo "$pass" | nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512 -s 2>/dev/null) || true
        fi
    fi

    echo "$hash"
}

setup_password() {
    step "Phase 4 — Password setup"

    if [ -f "$PASSWORD_FILE" ]; then
        local perms owner
        perms=$(stat -c '%a' "$PASSWORD_FILE" 2>/dev/null || echo "???")
        owner=$(stat -c '%U:%G' "$PASSWORD_FILE" 2>/dev/null || echo "?:?")
        ok "Password file already exists ($perms $owner) — skipping."
        return 0
    fi

    info "Setting up user password for '${USERNAME}'."
    info "This will be hashed and written to ${PASSWORD_FILE}"

    local password password2 hash
    local attempts=0
    while [ $attempts -lt 3 ]; do
        read_silent "Enter password" password
        read_silent "Confirm password" password2

        if [ "$password" != "$password2" ]; then
            warn "Passwords do not match."
            attempts=$((attempts + 1))
            continue
        fi

        if [ ${#password} -lt 8 ]; then
            warn "Password must be at least 8 characters."
            attempts=$((attempts + 1))
            continue
        fi

        break
    done

    if [ $attempts -ge 3 ]; then
        error "Too many failed attempts."
    fi

    info "Hashing password..."
    hash=$(hash_password "$password")

    if [ -z "$hash" ]; then
        error "Failed to hash password. Install mkpasswd or openssl."
    fi

    # Write the hash
    run_sudo mkdir -p "$(dirname "$PASSWORD_FILE")"
    echo "$hash" | run_sudo tee "$PASSWORD_FILE" > /dev/null
    run_sudo chmod 0400 "$PASSWORD_FILE"
    run_sudo chown root:root "$PASSWORD_FILE"

    # Verify
    if [ -f "$PASSWORD_FILE" ]; then
        ok "Password written to ${PASSWORD_FILE}"
        ok "Permissions: $(stat -c '%a %U:%G' "$PASSWORD_FILE")"
    else
        error "Failed to create password file."
    fi

    # Zero the variables
    password=""; password2=""; hash=""
}

# ═══════════════════════════════════════════════════════════
# PHASE 5 — PERSISTENT DIRECTORIES
# ═══════════════════════════════════════════════════════════

setup_persist_dirs() {
    step "Phase 5 — Persistent directories"

    info "Creating persistent directories under /persist..."

    local dirs=(
        "/etc/NetworkManager/system-connections"
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/bluetooth"
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/timers"
        "/var/lib/docker"
        "/var/db/sudo"
        "/etc/ssh"
    )

    for d in "${dirs[@]}"; do
        local full_path="${PERSIST_DIR}${d}"
        if [ -d "$full_path" ]; then
            ok "Exists: ${full_path}"
        else
            info "Creating: ${full_path}"
            run_sudo mkdir -p "$full_path"
            ok "Created: ${full_path}"
        fi
    done

    # /var/db/sudo — restrictive permissions
    local sudo_dir="${PERSIST_DIR}/var/db/sudo"
    local sudo_perms
    sudo_perms=$(stat -c '%a' "$sudo_dir" 2>/dev/null || echo "")
    if [ "$sudo_perms" != "700" ]; then
        run_sudo chmod 0700 "$sudo_dir"
        ok "Set permissions 0700 on ${sudo_dir}"
    fi

    # /etc/ssh — restrictive permissions
    local ssh_dir="${PERSIST_DIR}/etc/ssh"
    local ssh_perms
    ssh_perms=$(stat -c '%a' "$ssh_dir" 2>/dev/null || echo "")
    if [ "$ssh_perms" != "700" ]; then
        run_sudo chmod 0700 "$ssh_dir"
        ok "Set permissions 0700 on ${ssh_dir}"
    fi

    # /persist/passwords — restrictive permissions
    local pw_dir="$(dirname "$PASSWORD_FILE")"
    if [ -d "$pw_dir" ]; then
        local pw_perms
        pw_perms=$(stat -c '%a' "$pw_dir" 2>/dev/null || echo "")
        if [ "$pw_perms" != "700" ]; then
            run_sudo chmod 0700 "$pw_dir"
            ok "Set permissions 0700 on ${pw_dir}"
        fi
    fi

    # Home directory
    local home_dir="${PERSIST_DIR}/home/${USERNAME}"
    if [ ! -d "$home_dir" ]; then
        info "Creating home directory: ${home_dir}"
        run_sudo mkdir -p "$home_dir"
    fi

    local home_owner
    home_owner=$(stat -c '%U:%G' "$home_dir" 2>/dev/null || echo "")
    if [ "$home_owner" != "${USERNAME}:users" ]; then
        run_sudo chown "${USERNAME}:users" "$home_dir"
        ok "Home directory ownership set to ${USERNAME}:users"
    else
        ok "Home directory: ${home_dir} (${home_owner})"
    fi
}

# ═══════════════════════════════════════════════════════════
# PHASE 6 — NIXOS SYMLINK + REBUILD
# ═══════════════════════════════════════════════════════════

setup_nixos_symlink() {
    step "Phase 6 — NixOS symlink & rebuild"

    info "Setting up /etc/nixos..."

    if [ -L /etc/nixos ]; then
        local target
        target=$(readlink -f /etc/nixos 2>/dev/null || readlink /etc/nixos)
        if [ "$target" = "$NIXOS_DIR" ]; then
            ok "/etc/nixos already symlinked → ${NIXOS_DIR}"
        else
            warn "/etc/nixos points to ${target}, expected ${NIXOS_DIR}"
            if confirm "Update symlink to ${NIXOS_DIR}?"; then
                run_sudo rm /etc/nixos
                run_sudo ln -sfn "$NIXOS_DIR" /etc/nixos
                ok "Updated /etc/nixos → ${NIXOS_DIR}"
            fi
        fi
        FLAKE_ARG="/etc/nixos#nixos"
    elif mountpoint -q /etc/nixos 2>/dev/null; then
        warn "/etc/nixos is a mount point (impermanence bind mount)."
        info "Using direct flake path for rebuild: ${NIXOS_DIR}#nixos"
        info "After reboot, the tmpfiles rule will create the symlink automatically."
        FLAKE_ARG="${NIXOS_DIR}#nixos"
        ok "Using flake: ${FLAKE_ARG}"
    elif [ -d /etc/nixos ]; then
        warn "/etc/nixos is a regular directory."
        if confirm "Back up to /etc/nixos.bak and replace with symlink?"; then
            run_sudo cp -r /etc/nixos /etc/nixos.bak
            run_sudo rm -rf /etc/nixos
            run_sudo ln -sfn "$NIXOS_DIR" /etc/nixos
            ok "/etc/nixos → ${NIXOS_DIR} (backup at /etc/nixos.bak)"
            FLAKE_ARG="/etc/nixos#nixos"
        else
            warn "Skipping symlink setup. Using direct flake path."
            FLAKE_ARG="${NIXOS_DIR}#nixos"
        fi
    else
        info "/etc/nixos does not exist — creating symlink."
        run_sudo ln -sfn "$NIXOS_DIR" /etc/nixos
        ok "/etc/nixos → ${NIXOS_DIR}"
        FLAKE_ARG="/etc/nixos#nixos"
    fi
}

maybe_update_flake_lock() {
    if confirm_or_skip "Update flake.lock to latest inputs? (recommended for fresh installs)"; then
        info "Updating flake.lock..."
        run nix flake update --flake "$NIXOS_DIR"
        ok "flake.lock updated"
    fi
}

check_disk_space() {
    local min_gb=8
    local available_gb

    # Check space on /nix (or / if /nix is not a separate bind mount)
    if [ -d /nix/store ]; then
        available_gb=$(df -BG /nix 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}' || echo "?")
    else
        available_gb=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}' || echo "?")
    fi

    if [ "$available_gb" != "?" ]; then
        if [ "$available_gb" -lt "$min_gb" ] 2>/dev/null; then
            warn "Only ~${available_gb}G available (recommended: ${min_gb}G+)."
            warn "The first nixos-rebuild may download 2-5GB and need build space."
            confirm "Continue despite low disk space?" || exit 1
        else
            ok "Disk space: ~${available_gb}G available"
        fi
    else
        warn "Could not determine available disk space."
    fi
}

rebuild_nixos() {
    info "Starting nixos-rebuild switch..."
    info "This may take 30+ minutes on first run (downloading and building packages)."
    echo ""

    if $DRY_RUN; then
        echo -e "       ${YELLOW}[DRY-RUN]${NC} sudo nixos-rebuild switch --flake ${FLAKE_ARG} --show-trace"
        return 0
    fi

    if sudo nixos-rebuild switch --flake "$FLAKE_ARG" --show-trace; then
        ok "nixos-rebuild completed successfully!"
        return 0
    else
        local rc=$?
        echo ""
        warn "nixos-rebuild failed (exit code: $rc)."
        echo ""
        info "Common causes and fixes:"
        echo "  - Network error → check internet and retry"
        echo "  - Flake lock outdated → run: nix flake update --flake ${NIXOS_DIR}"
        echo "  - Windows ESP not found → edit configuration.nix to remove/guard references"
        echo "  - Insufficient space → free up space and retry"
        echo "  - NVIDIA driver mismatch → check hardware.nvidia settings"
        echo ""

        if confirm "Retry nixos-rebuild?"; then
            rebuild_nixos
        else
            warn "Skipping rebuild. You can run it later with: make rebuild"
        fi
        return $rc
    fi
}

run_nixos_setup() {
    setup_nixos_symlink
    maybe_update_flake_lock
    check_disk_space

    if $SKIP_REBUILD; then
        warn "Skipping nixos-rebuild (--skip-rebuild flag set)."
        return 0
    fi

    if confirm_or_skip "Proceed with nixos-rebuild? (first build may take 30+ min)"; then
        rebuild_nixos
    fi
}

# ═══════════════════════════════════════════════════════════
# PHASE 7 — DOTFILES DEPLOYMENT
# ═══════════════════════════════════════════════════════════

deploy_dotfiles() {
    step "Phase 7 — Dotfiles deployment"

    local config_src="${REPO_DIR}/.config"
    local config_dst="${HOME}/.config"

    if [ ! -d "$config_src" ]; then
        warn "${config_src} not found — skipping dotfiles."
        return 0
    fi

    run mkdir -p "$config_dst"

    local deployed=0 skipped=0
    for dir in "$config_src"/*; do
        [ -d "$dir" ] || continue
        local target_name
        target_name=$(basename "$dir")
        local link="${config_dst}/${target_name}"

        # DankMaterialShell's config dir is owned by DMS (settings.json, themes/)
        # and must never become a symlink — only individual plugins are linked
        # below.
        if [ "$target_name" = "DankMaterialShell" ]; then
            info "Skipping ${target_name} (DMS-owned config — plugins linked below)"
            skipped=$((skipped + 1))
            continue
        fi

        if [ -L "$link" ]; then
            local current_target
            current_target=$(readlink -f "$link" 2>/dev/null || readlink "$link")
            if [ "$current_target" = "$dir" ]; then
                ok "Already linked: ${target_name}"
                skipped=$((skipped + 1))
                continue
            else
                info "Updating symlink: ${target_name} (was → ${current_target})"
                run rm "$link"
            fi
        elif [ -d "$link" ] || [ -f "$link" ]; then
            local backup="${link}.bak.$(date +%Y%m%d%H%M%S)"
            info "Backing up: ${link} → ${backup}"
            run mv "$link" "$backup"
        fi

        run ln -sfn "$dir" "$link"
        ok "Linked: ${target_name} → ${link}"
        deployed=$((deployed + 1))
    done

    # DankMaterialShell plugins: link each plugin dir individually into the
    # DMS-owned config dir, leaving settings.json/themes as real files.
    local dms_plugins_src="${config_src}/DankMaterialShell/plugins"
    if [ -d "$dms_plugins_src" ]; then
        run mkdir -p "${config_dst}/DankMaterialShell/plugins"
        for pdir in "$dms_plugins_src"/*; do
            [ -d "$pdir" ] || continue
            local plugin_name
            plugin_name=$(basename "$pdir")
            local plink="${config_dst}/DankMaterialShell/plugins/${plugin_name}"

            if [ -L "$plink" ]; then
                local pcurrent_target
                pcurrent_target=$(readlink -f "$plink" 2>/dev/null || readlink "$plink")
                if [ "$pcurrent_target" = "$pdir" ]; then
                    ok "Already linked DMS plugin: ${plugin_name}"
                    continue
                else
                    info "Updating symlink: ${plugin_name} (was → ${pcurrent_target})"
                    run rm "$plink"
                fi
            elif [ -e "$plink" ]; then
                local pbackup="${plink}.bak.$(date +%Y%m%d%H%M%S)"
                info "Backing up: ${plink} → ${pbackup}"
                run mv "$plink" "$pbackup"
            fi

            run ln -sfn "$pdir" "$plink"
            ok "Linked DMS plugin: ${plugin_name} → ${plink}"
        done
    fi

    # Ensure scripts are executable
    local scripts_dir="${REPO_DIR}/.config/hypr/scripts"
    if [ -d "$scripts_dir" ]; then
        for script in "$scripts_dir"/*.sh; do
            [ -f "$script" ] || continue
            if [ ! -x "$script" ]; then
                run chmod +x "$script"
                ok "Made executable: $(basename "$script")"
            fi
        done
    fi

    # yay hooks
    local yay_hook="${REPO_DIR}/.config/yay/init.lua"
    if [ -f "$yay_hook" ] && [ ! -x "$yay_hook" ]; then
        run chmod +x "$yay_hook"
    fi

    echo ""
    info "Dotfiles: ${deployed} deployed, ${skipped} already up-to-date"
}

# ═══════════════════════════════════════════════════════════
# PHASE 8 — VALIDATION + SUMMARY
# ═══════════════════════════════════════════════════════════

validate_setup() {
    step "Phase 8 — Validation"

    local all_ok=true
    local issues=()

    # Check /etc/nixos
    if [ -L /etc/nixos ]; then
        ok "/etc/nixos → $(readlink /etc/nixos)"
    elif mountpoint -q /etc/nixos 2>/dev/null; then
        ok "/etc/nixos is a mount point (will become symlink after rebuild+reboot)"
    elif [ -d /etc/nixos ]; then
        warn "/etc/nixos is a directory (not yet symlinked)"
        issues+=("/etc/nixos not symlinked")
        all_ok=false
    else
        warn "/etc/nixos missing"
        issues+=("/etc/nixos missing")
        all_ok=false
    fi

    # Check password file
    if [ -f "$PASSWORD_FILE" ]; then
        local pw_perms pw_owner
        pw_perms=$(stat -c '%a' "$PASSWORD_FILE")
        pw_owner=$(stat -c '%U:%G' "$PASSWORD_FILE")
        if [ "$pw_perms" = "400" ] && [ "$pw_owner" = "root:root" ]; then
            ok "Password file: ${PASSWORD_FILE} (${pw_perms} ${pw_owner})"
        else
            warn "Password file has unexpected permissions: ${pw_perms} ${pw_owner}"
            issues+=("Password file permissions: ${pw_perms} ${pw_owner} (expected 400 root:root)")
            all_ok=false
        fi
    else
        warn "Password file not found at ${PASSWORD_FILE}"
        issues+=("Password file missing")
        all_ok=false
    fi

    # Spot-check dotfile symlinks
    local checks=(
        "${HOME}/.zshrc"
        "${HOME}/.config/hypr"
        "${HOME}/.config/nvim"
        "${HOME}/.config/quickshell"
    )
    for check in "${checks[@]}"; do
        if [ -L "$check" ]; then
            ok "Dotfile linked: ${check}"
        else
            warn "Dotfile not linked: ${check}"
            issues+=("${check} not symlinked")
            all_ok=false
        fi
    done

    # Check NixOS version
    if command -v nixos-version &>/dev/null; then
        ok "NixOS: $(nixos-version)"
    fi

    echo ""
    if $all_ok; then
        ok "All checks passed!"
    else
        warn "Some checks had issues:"
        for issue in "${issues[@]}"; do
            echo "       - $issue"
        done
    fi
}

print_summary() {
    echo ""
    echo -e "${CYAN}${BOLD}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│${NC}  ${BOLD}NixOS Dotfiles Installer — Complete!${NC}        ${CYAN}${BOLD}│${NC}"
    echo -e "${CYAN}${BOLD}├──────────────────────────────────────────────┤${NC}"
    if command -v nixos-version &>/dev/null; then
        printf "${CYAN}${BOLD}│${NC}  System:    %-34s ${CYAN}${BOLD}│${NC}\n" "$(nixos-version)"
    fi
    if [ -n "${BOOT_DEV:-}" ]; then
        printf "${CYAN}${BOLD}│${NC}  Boot:      %-34s ${CYAN}${BOLD}│${NC}\n" "${BOOT_DEV} (nixos-boot)"
    fi
    if [ -n "${PERSIST_DEV:-}" ]; then
        printf "${CYAN}${BOLD}│${NC}  Persist:   %-34s ${CYAN}${BOLD}│${NC}\n" "${PERSIST_DEV} (nixos-persist)"
    fi
    if [ -f "$PASSWORD_FILE" ]; then
        printf "${CYAN}${BOLD}│${NC}  Password:  %-34s ${CYAN}${BOLD}│${NC}\n" "$PASSWORD_FILE"
    fi
    printf "${CYAN}${BOLD}│${NC}  Config:    %-34s ${CYAN}${BOLD}│${NC}\n" "${NIXOS_DIR}"
    printf "${CYAN}${BOLD}│${NC}  Dotfiles:  %-34s ${CYAN}${BOLD}│${NC}\n" "\$HOME/.config/"
    echo -e "${CYAN}${BOLD}├──────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}${BOLD}│${NC}  ${BOLD}Next steps:${NC}                                 ${CYAN}${BOLD}│${NC}"
    echo -e "${CYAN}${BOLD}│${NC}  • Reboot to apply all changes               ${CYAN}${BOLD}│${NC}"
    echo -e "${CYAN}${BOLD}│${NC}  • Select Hyprland at SDDM                     ${CYAN}${BOLD}│${NC}"
    echo -e "${CYAN}${BOLD}│${NC}  • Run: make rebuild  (update system config)  ${CYAN}${BOLD}│${NC}"
    echo -e "${CYAN}${BOLD}│${NC}  • Run: make deploy   (update dotfiles)       ${CYAN}${BOLD}│${NC}"
    echo -e "${CYAN}${BOLD}└──────────────────────────────────────────────┘${NC}"
    echo ""
    ok "Done! Your NixOS system is configured."
}

# ═══════════════════════════════════════════════════════════
# GUIDE — ISO INSTALL STEPS
# ═══════════════════════════════════════════════════════════

print_iso_guide() {
    cat <<'GUIDE'
NixOS Dotfiles — Prerequisite ISO Installation Guide
────────────────────────────────────────────────────

Before running install.sh, NixOS must be installed with the
correct partition layout for impermanence (tmpfs root).

1. Boot the NixOS minimal ISO.

2. Partition your disk. Example for NVMe (/dev/nvme0n1):
   ┌────────────────┬────────┬──────────────────────────────┐
   │ Partition      │ Size   │ Purpose                      │
   ├────────────────┼────────┼──────────────────────────────┤
   │ nvme0n1p1      │ 512M+  │ ESP (vfat)  → /boot          │
   │ nvme0n1p2      │ rest   │ Persist (ext4) → /persist    │
   └────────────────┴────────┴──────────────────────────────┘

   parted /dev/nvme0n1 -- mklabel gpt
   parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 513MiB
   parted /dev/nvme0n1 -- set 1 esp on
   parted /dev/nvme0n1 -- mkpart primary ext4 513MiB 100%

3. Format:
   mkfs.fat -F 32 /dev/nvme0n1p1
   mkfs.ext4 /dev/nvme0n1p2

4. Label (optional but recommended):
   fatlabel /dev/nvme0n1p1 nixos-boot
   e2label /dev/nvme0n1p2 nixos-persist

5. Mount:
   mount /dev/nvme0n1p2 /mnt
   mkdir -p /mnt/{boot,persist/nix,persist/home/persist/home/giovani}
   mount /dev/nvme0n1p1 /mnt/boot

6. Clone the dotfiles repo:
   mkdir -p /mnt/home/giovani/dev
   git clone https://github.com/giovani/dotfiles.git /mnt/home/giovani/dev/dotfiles

7. Generate hardware-configuration.nix (to get correct UUIDs):
   nixos-generate-config --root /mnt
   # Copy the generated UUIDs into the repo's hardware-configuration.nix,
   # preserving the tmpfs root and bind mount structure.

8. Create the password hash:
   mkdir -p /mnt/persist/passwords
   mkpasswd -m sha-512 > /mnt/persist/passwords/giovani
   chmod 0400 /mnt/persist/passwords/giovani

9. Install:
   nixos-install --flake /mnt/home/giovani/dev/dotfiles/nixos#nixos --root /mnt

10. Reboot, log in as giovani, then run:
    cd ~/dev/dotfiles && ./install.sh

────────────────────────────────────────────────────
GUIDE
}

# ═══════════════════════════════════════════════════════════
# USAGE
# ═══════════════════════════════════════════════════════════

show_usage() {
    cat <<EOF
Usage: install.sh [OPTIONS]

NixOS Dotfiles Installer v${SCRIPT_VERSION}
Configures a freshly-installed NixOS system with impermanence,
Hyprland and all app dotfiles.

Options:
  -y, --yes          Auto-confirm all prompts (non-interactive)
  --dry-run          Show what would be done without executing
  --skip-rebuild     Skip nixos-rebuild (dotfiles and setup only)
  --guide-iso        Print prerequisite ISO installation steps
  -h, --help         Show this help message

EOF
}

# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-rebuild)
                SKIP_REBUILD=true
                shift
                ;;
            --guide-iso)
                print_iso_guide
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1\n       Run with --help for usage."
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    echo ""
    echo -e "${CYAN}${BOLD}  NixOS Dotfiles Installer v${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}  ─────────────────────────────────${NC}"
    echo ""

    if $DRY_RUN; then
        warn "DRY RUN — no changes will be made."
        echo ""
    fi

    # Phase 0: Bootstrap (curl mode)
    bootstrap_from_curl "$@"

    # Update REPO_DIR and derived paths now that we're in the repo
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_DIR="$script_dir"
    NIXOS_DIR="${REPO_DIR}/nixos"

    # Phase 1
    run_preflight

    # Phase 2
    run_partition_setup

    # Phase 3
    run_hardware_validation

    # Phase 4
    setup_password

    # Phase 5
    setup_persist_dirs

    # Phase 6
    run_nixos_setup

    # Phase 7
    deploy_dotfiles

    # Phase 8
    validate_setup
    print_summary
}

main "$@"
