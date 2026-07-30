# Daily-use NixOS commands have been moved to .zshrc functions.
# After 'make deploy', run 'source ~/.zshrc' to use:
#   nixos-rebuild-switch    (was: nixos-rebuild-switch)
#   nixos-check             (was: make check)
#   nixos-clean-broken-generations  (was: make clean-broken-generations)

.PHONY: deploy setup-nixos

# Symlink .zshrc to ~/ and every dir under .config/ into ~/.config/
deploy:
	@mkdir -p $(HOME)/.config
	@# Symlink .zshrc
	@zshrc_link="$(HOME)/.zshrc"; \
	zshrc_src="$(CURDIR)/.zshrc"; \
	if [ -L "$$zshrc_link" ]; then \
		rm "$$zshrc_link"; \
	elif [ -f "$$zshrc_link" ]; then \
		echo "Backing up $$zshrc_link → $${zshrc_link}.bak"; \
		mv "$$zshrc_link" "$${zshrc_link}.bak"; \
	fi; \
	ln -sfn "$$zshrc_src" "$$zshrc_link"; \
	echo ".zshrc → $$zshrc_link"
	@# Symlink .config dirs
	@for dir in $(CURDIR)/.config/*; do \
		target="$$(basename "$$dir")"; \
		link="$(HOME)/.config/$$target"; \
		if [ -L "$$link" ]; then \
			rm "$$link"; \
		elif [ -d "$$link" ] || [ -f "$$link" ]; then \
			echo "Backing up $$link → $${link}.bak"; \
			mv "$$link" "$${link}.bak"; \
		fi; \
		ln -sfn "$$dir" "$$link"; \
		echo "$$target → $$link"; \
	done

# Symlink /etc/nixos → repo (one-time setup)
# If /etc/nixos is a bind mount (impermanence), run `nixos-rebuild-switch` first,
# then reboot — the tmpfiles rule will create the symlink.
setup-nixos:
	@if [ -L /etc/nixos ]; then \
		echo "/etc/nixos is already a symlink → $$(readlink /etc/nixos)"; \
	elif mountpoint -q /etc/nixos 2>/dev/null; then \
		echo "/etc/nixos is a mount point (impermanence). Run these steps:"; \
		echo "  1. nixos-rebuild-switch    # builds directly from $(CURDIR)/nixos"; \
		echo "  2. sudo reboot     # tmpfiles rule creates the symlink on boot"; \
	elif [ "$$(findmnt -n -o FSTYPE / 2>/dev/null)" = "tmpfs" ]; then \
		echo "Detected tmpfs root (impermanence)."; \
		if grep -rq '^[[:space:]]*"L+\? /etc/nixos' $(CURDIR)/nixos/ 2>/dev/null; then \
			echo "The tmpfiles rule for /etc/nixos is present in your config."; \
			echo "Run: nixos-rebuild-switch && sudo reboot"; \
			echo "On boot, the tmpfiles rule will create the symlink."; \
		else \
			echo "ERROR: tmpfs root detected but no tmpfiles rule found."; \
			echo 'Add this to configuration.nix, then rebuild and reboot:'; \
			echo '  systemd.tmpfiles.rules = [ "L+ /etc/nixos - - - - /home/giovani/dev/dotfiles/nixos" ];'; \
			exit 1; \
		fi; \
	else \
		echo "Backing up /etc/nixos → /etc/nixos.bak"; \
		sudo cp -r /etc/nixos /etc/nixos.bak; \
		sudo rm -rf /etc/nixos; \
		sudo ln -sfn $(CURDIR)/nixos /etc/nixos; \
		echo "/etc/nixos → $(CURDIR)/nixos"; \
	fi
