package voice

import "math"

// VADEvent is what a frame changed in the detector.
type VADEvent int

const (
	VADNone VADEvent = iota
	// VADSpeechStart fires once speech has lasted startFrames frames.
	VADSpeechStart
	// VADSpeechEnd fires after silenceMs of silence following speech
	// (the hangover), i.e. when an utterance is complete.
	VADSpeechEnd
)

// EnergyVAD is a frame-energy voice activity detector. The noise floor is
// the minimum frame energy over a sliding window (minimum statistics), so
// it adapts to steady background noise and still works when speech starts
// on the very first frame. A hangover keeps short pauses inside one
// utterance. It is only used live, to auto-stop and to detect "nothing was
// said"; the whisper server additionally trims silence with Silero VAD.
type EnergyVAD struct {
	ratio       float64 // energy above the noise floor counted as speech
	minEnergy   float64 // absolute floor (-55 dBFS) so silence never triggers
	startFrames int
	endFrames   int

	window    []float64 // ring of recent frame energies
	pos       int
	filled    int
	run       int // consecutive speech frames
	silence   int // consecutive silent frames after speech
	inSpeech  bool
	hadSpeech bool
}

// noiseWindowFrames is the minimum-statistics window (~2 s).
const noiseWindowFrames = 62

// NewEnergyVAD builds a detector. sensitivity 0..1 (higher = triggers on
// quieter speech); silenceMs is the hangover before VADSpeechEnd.
func NewEnergyVAD(sensitivity float64, silenceMs int) *EnergyVAD {
	frameMs := float64(FrameSamples) * 1000 / SampleRate
	// sensitivity 1 → +4 dB over the floor, 0 → +12 dB
	ratioDb := 12 - 8*clamp01(sensitivity)
	return &EnergyVAD{
		ratio:       math.Pow(10, ratioDb/10),
		minEnergy:   math.Pow(10, -55.0/10),
		startFrames: 3,
		endFrames:   int(math.Ceil(float64(silenceMs) / frameMs)),
		window:      make([]float64, noiseWindowFrames),
	}
}

// HadSpeech reports whether any speech was detected so far.
func (v *EnergyVAD) HadSpeech() bool { return v.hadSpeech }

// InSpeech reports whether the detector is inside an utterance.
func (v *EnergyVAD) InSpeech() bool { return v.inSpeech }

func (v *EnergyVAD) noiseFloor() float64 {
	floor := math.Inf(1)
	for i := 0; i < v.filled; i++ {
		floor = math.Min(floor, v.window[i])
	}
	return math.Max(floor, v.minEnergy/100)
}

// Push feeds one frame energy (FrameEnergy) and returns the transition.
func (v *EnergyVAD) Push(e float64) VADEvent {
	v.window[v.pos] = e
	v.pos = (v.pos + 1) % len(v.window)
	if v.filled < len(v.window) {
		v.filled++
	}
	speech := e > v.noiseFloor()*v.ratio && e > v.minEnergy
	if speech {
		v.run++
		v.silence = 0
		if !v.inSpeech && v.run >= v.startFrames {
			v.inSpeech = true
			v.hadSpeech = true
			return VADSpeechStart
		}
		return VADNone
	}
	v.run = 0
	if v.inSpeech {
		v.silence++
		if v.silence >= v.endFrames {
			v.inSpeech = false
			v.silence = 0
			return VADSpeechEnd
		}
	}
	return VADNone
}
