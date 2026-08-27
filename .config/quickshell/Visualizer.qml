// Audio visualizer: replaces cava with the native PipeWire peak monitor.
// 16 bars shaped from the sink peak (center-weighted envelope, stereo mirrored
// when 2 channels are present), 30fps with smoothed attack and exponential
// decay, hidden when silent. Quickshell 0.3 has no FFT monitor, so per-bar
// random drift emulates independent frequency bands.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
	id: root

	width: root.silent ? 0 : 63 // 16 bars x (3px + 1px gap) - 1
	height: Theme.barHeight
	visible: !root.silent // collapse entirely (no reserved space) when silent

	property var heights: new Array(16).fill(0)
	property var wobble: new Array(16).fill(1)
	property int version: 0
	property bool silent: true
	property real maxHeight: 0

	// Tuning knobs — gate: peaks below this count as silence; gain: overall
	// boost (full height needs peak > 1/gain); power: response curve exponent
	// (higher = quieter response); maxRise: max px a bar may grow per tick
	// (attack smoothing, less twitch).
	property real gate: 0.03
	property real gain: 1.4
	property real power: 1.5
	property real maxRise: 1.2

	PwNodePeakMonitor {
		id: mon
		node: Pipewire.defaultAudioSink
	}

	Timer {
		interval: 33
		repeat: true
		running: true
		onTriggered: root.tick()
	}

	function tick() {
		// gate out the noise floor, then a power curve so quiet audio stays
		// subtle and only real sound drives the bars up (less twitchy)
		const scale = v => {
			const gated = Number.isFinite(v) && v > root.gate ? v : 0
			return Math.pow(Math.min(1, gated * root.gain), root.power)
		}
		const p = scale(mon.peak)
		let m = 0
		for (let i = 0; i < 16; i++) {
			// center-weighted shape; mirror left/right channels when available
			const shape = 0.25 + 0.75 * Math.pow(Math.cos(Math.PI * (i - 7.5) / 16), 2)
			let gain = p
			if (mon.peaks && mon.peaks.length >= 2) {
				const ch = i < 8 ? mon.peaks[0] : mon.peaks[1]
				gain = Math.max(p, scale(ch))
			}
			// stereo peaks are near-identical and there's no FFT, so bars would
			// rise in lockstep — drift each bar's multiplier randomly
			wobble[i] = wobble[i] * 0.9 + (0.55 + Math.random() * 0.9) * 0.1
			const target = Math.min(16, gain * shape * wobble[i] * 16)
			// limit how fast a bar can rise so transients don't twitch
			heights[i] = target > heights[i]
				? Math.min(target, heights[i] + root.maxRise)
				: Math.max(target, heights[i] * 0.85)
			m = Math.max(m, heights[i])
		}
		maxHeight = m
		// hide on silence, with a little hysteresis so it doesn't flicker
		if (m > 2.5) silent = false
		else if (m < 0.8) silent = true
		version++
	}

	Repeater {
		model: 16
		delegate: Rectangle {
			x: index * 4
			width: 3
			height: barHeight
			y: 22 - barHeight // bottom margin 6
			color: Theme.audio
			opacity: root.silent ? 0 : 1

			Behavior on opacity {
				NumberAnimation { duration: 120 }
			}

			property real barHeight: {
				root.version
				return Math.max(1.5, root.heights[index])
			}
		}
	}
}
