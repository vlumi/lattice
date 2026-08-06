#!/usr/bin/env swift
//
// Procedural sound effects — the audio counterpart to the procedural app icon
// (IconArt). Percussive, minimal, entirely synthesised: no samples, no
// licensing, tunable by editing the numbers below. Emits three short mono CAF
// files into the LatticeKit resource bundle:
//
//   select   — a scrub-highlight blip (soft, quiet; may fire several times as
//              the finger sweeps between candidate lines — kept very faint)
//   place    — a line committed (a crisp, slightly fuller click)
//   gameover — no moves left (a calm, neutral two-note settling tone; not a
//              triumphant fanfare — the game just ended)
//
//   swift Scripts/make-sounds.swift
//
// Deterministic (fixed noise seed), so re-running yields byte-identical files —
// they're committed like the icon assets. Adapted from Donpa's make-sounds.swift
// (plumbing kept in sync with the sibling app; Donpa leads).

import AVFoundation
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let outDir = root.appendingPathComponent(
    "Packages/LatticeCore/Sources/LatticeKit/Resources/Sounds")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sampleRate = 44_100.0

// A tiny deterministic LCG so the noise bursts are identical run to run (the
// files are committed; `Double.random` would churn them every regeneration).
struct SeededNoise {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 32) / Double(UInt32.max) * 2 - 1
    }
}

/// Synthesise `seconds` of mono audio with `sample(i, t)` → [-1, 1], and write it
/// as a CAF. A short raised-cosine fade-out on the last 5 ms kills the end click.
func write(_ name: String, seconds: Double, sample: (Int, Double) -> Double) throws {
    let frames = Int(seconds * sampleRate)
    let fadeFrames = min(frames, Int(0.005 * sampleRate))
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
    buffer.frameLength = AVAudioFrameCount(frames)
    let out = buffer.floatChannelData![0]
    for i in 0..<frames {
        let t = Double(i) / sampleRate
        var v = sample(i, t)
        let remaining = frames - i
        if remaining < fadeFrames {
            v *= 0.5 * (1 - cos(.pi * Double(remaining) / Double(fadeFrames)))
        }
        out[i] = Float(max(-1, min(1, v)))
    }
    let url = outDir.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
    print("  \(name)")
}

func env(_ t: Double, _ decay: Double) -> Double { exp(-t / decay) }

print("Generating sounds into \(outDir.path):")

// select — a very soft, quiet high blip for a scrub-highlight change. Kept
// faint: it can fire several times across one finger sweep, and the haptic is
// the primary cue. A short 1.2 kHz tick.
try write("select.caf", seconds: 0.03) { _, t in
    0.14 * sin(2 * .pi * 1_200 * t) * env(t, 0.006)
}

// place — a brighter, slightly fuller click when a line commits: a crisp
// 1.9 kHz click with a tiny noise transient and a short low body.
var noise = SeededNoise(state: 0x1234_5678)
try write("place.caf", seconds: 0.06) { _, t in
    0.5 * sin(2 * .pi * 1_900 * t) * env(t, 0.008)
        + 0.18 * noise.next() * env(t, 0.003)
        + 0.1 * sin(2 * .pi * 420 * t) * env(t, 0.03)
}

// gameover — a calm, neutral two-note settling tone (a gentle DOWNWARD pair,
// E5 → A4): "that's the end", noticeable but not a fanfare or a defeat sting.
try write("gameover.caf", seconds: 0.45) { _, t in
    let n1 = 0.4 * sin(2 * .pi * 659.25 * t) * env(t, 0.16)  // E5
    let n2 = t > 0.11 ? 0.4 * sin(2 * .pi * 440 * (t - 0.11)) * env(t - 0.11, 0.22) : 0  // A4
    return tanh(1.1 * (n1 + n2))
}

print("Done.")
