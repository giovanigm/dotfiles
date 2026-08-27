// Quickshell status bar — Catppuccin Mocha, faithful replica of the old Waybar bar.
// Entry point: creates one Bar per monitor. Hot-reloads on save.
import Quickshell

ShellRoot {
	Variants {
		model: Quickshell.screens
		Bar {}
	}
}
