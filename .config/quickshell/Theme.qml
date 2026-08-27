// Catppuccin Mocha palette + typography, mirroring the old Waybar style.css.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
	// ── Colors (from .config/waybar/style.css @define-color block) ──
	readonly property color background1: "#202030" // rgba(32, 32, 48, 1)
	readonly property color background2: "#151520" // rgba(21, 21, 32, 1)
	readonly property color separator: "#313244"
	readonly property color warning: "#f38ba8"
	readonly property color caution: "#45475a"
	readonly property color performance: "#f5c2e7"
	readonly property color audio: "#cba6f7"
	readonly property color misc: "#94e2d5"
	readonly property color date: "#a6e3a1"
	readonly property color work: "#b4befe"
	readonly property color window: "#b4befe"
	readonly property color resize: "#eba0ac"
	readonly property color process: "#89b4fa"
	readonly property color text: "#cdd6f4"

	// ── Typography (waybar: 12pt 600 → 16px demi-bold) ──
	readonly property string fontFamily: "JetBrainsMono Nerd Font propo"
	readonly property int pixelSize: 16
	readonly property int fontWeight: Font.DemiBold

	// ── Geometry (waybar config: height 28, margins 12, radius 8) ──
	readonly property int barHeight: 28
	readonly property int barMargin: 12
	readonly property int barRadius: 8
	readonly property int modulePadding: 11 // 8pt @96dpi ≈ 10.7px

	// ── Plane-15 (5-digit) Nerd Font glyphs ──
	// These cannot be written as literal chars (they get truncated), so they
	// are built from codepoints at runtime.
	readonly property string glyphWifi0: String.fromCodePoint(0xF092B)
	readonly property string glyphWifi1: String.fromCodePoint(0xF091F)
	readonly property string glyphWifi2: String.fromCodePoint(0xF0922)
	readonly property string glyphWifi3: String.fromCodePoint(0xF0925)
	readonly property string glyphWifi4: String.fromCodePoint(0xF0928)
	readonly property string glyphEthernet: String.fromCodePoint(0xF0200)
	readonly property string glyphOffline: String.fromCodePoint(0xF1616)
	readonly property string glyphDown: String.fromCodePoint(0xF01DA)
	readonly property string glyphUp: String.fromCodePoint(0xF0552)
	readonly property string glyphWsTen: String.fromCodePoint(0xF02B4)
	readonly property string glyphResize: String.fromCodePoint(0xF0C8F)

	// ── Helpers ──
	function bits(n) {
		if (n < 1000) return Math.round(n) + " b/s"
		if (n < 1e6) return (n / 1e3).toFixed(1) + " Kb/s"
		if (n < 1e9) return (n / 1e6).toFixed(1) + " Mb/s"
		return (n / 1e9).toFixed(1) + " Gb/s"
	}
}
