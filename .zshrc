# =============================================================================
# .zshrc — version-controlled via ~/dev/dotfiles
# Deployed by 'make deploy' (symlink from ~/.zshrc)
# =============================================================================

# ── fvm (Flutter Version Management) ─────────────────────────────────────────
# After `fvm install 3.44 && fvm global 3.44`, this makes the global Flutter
# SDK available on PATH.
export FVM_CACHE_PATH="$HOME/.fvm"
export PATH="$FVM_CACHE_PATH/default/bin:$PATH"
export PATH="$HOME/.pub-cache/bin:$PATH"

alias nixos-rebuild-switch="sudo nixos-rebuild switch --flake /etc/nixos#nixos"
alias nixos-rebuild-boot="sudo nixos-rebuild boot --flake /etc/nixos#nixos"

# ── Syntax-check all .nix files in the repo ─────────────────────────────────
nixos-check() {
    local dir="${1:-$HOME/dev/dotfiles/nixos}"
    local all_ok=true
    echo "Checking nix files in $dir ..."
    while IFS= read -r -d '' f; do
        if nix-instantiate --parse "$f" >/dev/null 2>&1; then
            echo "  OK  ${f#$dir/}"
        else
            echo "  FAIL ${f#$dir/}"
            all_ok=false
        fi
    done < <(find "$dir" -name '*.nix' -print0)
    if $all_ok; then
        echo "All files OK."
    else
        echo "Some files have errors."
        return 1
    fi
}

# ── Update flake.lock + rebuild ─────────────────────────────────────────────
nixos-upgrade() {
    echo "Updating flake.lock..."
    (cd "$HOME/dev/dotfiles/nixos" && nix flake update) || return 1
    echo ""
    nixos-rebuild-switch
}

# ── View last NixOS build log ───────────────────────────────────────────────
nixos-build-log() {
    local log
    log=$(ls -t /nix/var/log/nix/drvs/*.drv* 2>/dev/null | head -1)
    if [ -n "$log" ]; then
        sudo nix-store -l "$log"
    else
        echo "No build logs found."
    fi
}

# ── Clean broken NixOS generations ───────────────────────────────────────────
# Switches to the currently booted generation, deletes all newer ones,
# then garbage-collects.
nixos-clean-broken-generations() {
    echo "====== NixOS Generation Cleanup ======"
    local booted
    booted=$(readlink -f /run/booted-system)
    local current
    current=$(readlink -f /run/current-system)
    local booted_gen=""

    for link in /nix/var/nix/profiles/system-*-link; do
        if [ "$(readlink -f "$link")" = "$booted" ]; then
            booted_gen=$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')
            break
        fi
    done < <(find "$dir" -name '*.nix' -print0)

    if [ -z "$booted_gen" ]; then
        echo "ERROR: Could not determine booted generation number."
        return 1
    fi

    echo "Booted generation: $booted_gen"
    echo "Current generation: $(basename "$(readlink /nix/var/nix/profiles/system)" | sed 's/system-\([0-9]*\)-link/\1/')"

    if [ "$booted" != "$current" ]; then
        echo "Switching to booted generation..."
        sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation "$booted_gen"
    fi

    echo ""
    echo "--- Deleting generations newer than $booted_gen ---"
    local deleted=0
    for link in /nix/var/nix/profiles/system-*-link; do
        local n
        n=$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')
        if [ "$n" -gt "$booted_gen" ] 2>/dev/null; then
            echo "  Deleting generation $n"
            sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations "$n"
            deleted=$((deleted + 1))
        fi
    done < <(find "$dir" -name '*.nix' -print0)

    if [ "$deleted" -eq 0 ]; then
        echo "  No newer generations to delete."
    fi

    echo ""
    echo "--- Running garbage collection ---"
    sudo nix-collect-garbage
    echo ""
    echo "====== Cleanup complete ======"
    echo "Run 'nixos-rebuild-switch' to update bootloader entries."
}
