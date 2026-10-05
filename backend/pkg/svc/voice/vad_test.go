package voice

import (
	"math/rand"
	"testing"
)

func TestVADDetectsUtteranceAndHangover(t *testing.T) {
	rng := rand.New(rand.NewSource(1))
	audio := concat(noise(rng, 0.8, -55), speechLike(rng, 1.5, -20), noise(rng, 2.5, -55))
	v := NewEnergyVAD(0.5, 1000)
	starts, ends := runVAD(v, audio)
	if len(starts) != 1 || len(ends) != 1 {
		t.Fatalf("want one utterance, got starts=%v ends=%v", starts, ends)
	}
	if s := frameSec(starts[0]); s < 0.8 || s > 1.0 {
		t.Errorf("speech start at %.2fs, want ~0.8-1.0s", s)
	}
	// speech ends at 2.3s; hangover 1.0s → ~3.3s
	if e := frameSec(ends[0]); e < 3.2 || e > 3.5 {
		t.Errorf("speech end at %.2fs, want ~3.3s (2.3s + 1s hangover)", e)
	}
	if !v.HadSpeech() || v.InSpeech() {
		t.Errorf("HadSpeech=%v InSpeech=%v", v.HadSpeech(), v.InSpeech())
	}
}

func TestVADIgnoresSteadyNoise(t *testing.T) {
	rng := rand.New(rand.NewSource(2))
	for _, db := range []float64{-70, -45, -30} { // silence, room, loud fan
		v := NewEnergyVAD(0.5, 800)
		starts, _ := runVAD(v, noise(rng, 4, db))
		if len(starts) != 0 {
			t.Errorf("%.0f dBFS noise triggered speech at %v", db, starts)
		}
	}
}

func TestVADSpeechOverLoudNoise(t *testing.T) {
	rng := rand.New(rand.NewSource(3))
	audio := concat(noise(rng, 1, -35), concatMix(speechLike(rng, 1.2, -15), noise(rng, 1.2, -35)), noise(rng, 2, -35))
	starts, ends := runVAD(NewEnergyVAD(0.5, 800), audio)
	if len(starts) != 1 || len(ends) != 1 {
		t.Fatalf("want one utterance over noise, got starts=%v ends=%v", starts, ends)
	}
}

func TestVADSpeechFromFirstFrame(t *testing.T) {
	rng := rand.New(rand.NewSource(4))
	audio := withRoom(rng, -55, speechLike(rng, 2, -20), noise(rng, 2, -90))
	starts, ends := runVAD(NewEnergyVAD(0.5, 800), audio)
	if len(starts) != 1 || frameSec(starts[0]) > 0.6 {
		t.Fatalf("speech at t=0 detected late or not at all: %v", starts)
	}
	if len(ends) != 1 {
		t.Fatalf("no end detected: %v", ends)
	}
}

func TestVADPausesWithinHangoverKeepUtterance(t *testing.T) {
	rng := rand.New(rand.NewSource(5))
	audio := concat(noise(rng, 0.5, -60), speechLike(rng, 0.8, -20), noise(rng, 0.4, -60),
		speechLike(rng, 0.8, -20), noise(rng, 2, -60))
	starts, ends := runVAD(NewEnergyVAD(0.5, 800), audio)
	if len(starts) != 1 || len(ends) != 1 {
		t.Fatalf("a 0.4s pause split the utterance: starts=%v ends=%v", starts, ends)
	}
}

func TestVADSensitivity(t *testing.T) {
	rng := rand.New(rand.NewSource(6))
	// quiet speech peaking ~8 dB over a quiet room (speechLike energy is ~7 dB under its nominal level)
	audio := withRoom(rng, -60, noise(rng, 1, -90), speechLike(rng, 1, -45), noise(rng, 1, -90))
	if s, _ := runVAD(NewEnergyVAD(1, 800), audio); len(s) == 0 {
		t.Error("high sensitivity missed quiet speech")
	}
	if s, _ := runVAD(NewEnergyVAD(0, 800), audio); len(s) != 0 {
		t.Error("low sensitivity triggered on quiet speech")
	}
}

func concatMix(a, b []int16) []int16 {
	out := make([]int16, len(a))
	for i := range a {
		v := int(a[i])
		if i < len(b) {
			v += int(b[i])
		}
		out[i] = int16(clampF(float64(v), -32767, 32767))
	}
	return out
}

// withRoom concatenates parts over a continuous room-noise bed, as a real
// microphone would hear them.
func withRoom(rng *rand.Rand, db float64, parts ...[]int16) []int16 {
	a := concat(parts...)
	return concatMix(a, noise(rng, float64(len(a))/SampleRate+0.1, db))
}
