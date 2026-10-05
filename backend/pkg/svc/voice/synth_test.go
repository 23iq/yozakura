package voice

import (
	"math"
	"math/rand"
)

// Synthetic audio for tests: no real microphone is ever touched.

// noise returns white noise at the given dBFS RMS.
func noise(rng *rand.Rand, seconds float64, db float64) []int16 {
	n := int(seconds * SampleRate)
	amp := math.Pow(10, db/20) * 32767
	out := make([]int16, n)
	for i := range out {
		out[i] = int16(clampF(rng.NormFloat64()*amp, -32767, 32767))
	}
	return out
}

// speechLike is a voiced signal: a 140 Hz glottal-ish harmonic stack,
// amplitude-modulated at a 4 Hz syllable rate, at roughly the given dBFS.
func speechLike(rng *rand.Rand, seconds float64, db float64) []int16 {
	n := int(seconds * SampleRate)
	amp := math.Pow(10, db/20) * 32767
	out := make([]int16, n)
	for i := range out {
		t := float64(i) / SampleRate
		env := 0.55 + 0.45*math.Sin(2*math.Pi*4*t)
		var v float64
		for h := 1; h <= 8; h++ {
			v += math.Sin(2*math.Pi*140*float64(h)*t) / float64(h)
		}
		v = v*0.6*env + rng.NormFloat64()*0.02
		out[i] = int16(clampF(v*amp, -32767, 32767))
	}
	return out
}

func concat(parts ...[]int16) []int16 {
	var out []int16
	for _, p := range parts {
		out = append(out, p...)
	}
	return out
}

func clampF(v, lo, hi float64) float64 { return math.Max(lo, math.Min(hi, v)) }

// runVAD feeds samples frame by frame and returns the frame index of each
// event.
func runVAD(v *EnergyVAD, s []int16) (starts, ends []int) {
	for i := 0; i+FrameSamples <= len(s); i += FrameSamples {
		switch v.Push(FrameEnergy(s[i : i+FrameSamples])) {
		case VADSpeechStart:
			starts = append(starts, i/FrameSamples)
		case VADSpeechEnd:
			ends = append(ends, i/FrameSamples)
		}
	}
	return
}

func frameSec(f int) float64 { return float64(f*FrameSamples) / SampleRate }
