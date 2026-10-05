package voice

import (
	"bytes"
	"encoding/binary"
	"math"
	"math/cmplx"
)

// Audio format captured from PipeWire: 16 kHz, mono, signed 16-bit LE.
const (
	SampleRate = 16000
	// FrameSamples is one analysis frame: 512 samples = 32 ms, so level
	// events stream at ~31 fps.
	FrameSamples = 512
	// BandCount is the number of visualizer bars sent with every level.
	BandCount = 24
)

// EncodeWAV wraps PCM samples in a minimal RIFF/WAVE header.
func EncodeWAV(samples []int16) []byte {
	var b bytes.Buffer
	dataLen := uint32(len(samples) * 2)
	b.WriteString("RIFF")
	_ = binary.Write(&b, binary.LittleEndian, 36+dataLen)
	b.WriteString("WAVEfmt ")
	_ = binary.Write(&b, binary.LittleEndian, uint32(16))
	_ = binary.Write(&b, binary.LittleEndian, uint16(1)) // PCM
	_ = binary.Write(&b, binary.LittleEndian, uint16(1)) // mono
	_ = binary.Write(&b, binary.LittleEndian, uint32(SampleRate))
	_ = binary.Write(&b, binary.LittleEndian, uint32(SampleRate*2))
	_ = binary.Write(&b, binary.LittleEndian, uint16(2))
	_ = binary.Write(&b, binary.LittleEndian, uint16(16))
	b.WriteString("data")
	_ = binary.Write(&b, binary.LittleEndian, dataLen)
	_ = binary.Write(&b, binary.LittleEndian, samples)
	return b.Bytes()
}

// DecodePCM converts little-endian s16 bytes to samples (odd byte dropped).
func DecodePCM(buf []byte) []int16 {
	out := make([]int16, len(buf)/2)
	for i := range out {
		out[i] = int16(binary.LittleEndian.Uint16(buf[2*i:]))
	}
	return out
}

// FrameEnergy is the mean square of a frame normalised to [0, 1].
func FrameEnergy(frame []int16) float64 {
	if len(frame) == 0 {
		return 0
	}
	var sum float64
	for _, s := range frame {
		v := float64(s) / 32768
		sum += v * v
	}
	return sum / float64(len(frame))
}

// LevelFromEnergy maps an energy to a 0..1 display level (-60..0 dBFS).
func LevelFromEnergy(e float64) float64 {
	if e <= 0 {
		return 0
	}
	db := 10 * math.Log10(e)
	return clamp01((db + 60) / 60)
}

// Bands returns BandCount log-spaced spectrum magnitudes (80 Hz..7 kHz) of
// a frame, each mapped to 0..1 like a cava bar.
func Bands(frame []int16) []float64 {
	n := FrameSamples
	buf := make([]complex128, n)
	for i := 0; i < n && i < len(frame); i++ {
		w := 0.5 - 0.5*math.Cos(2*math.Pi*float64(i)/float64(n-1)) // Hann
		buf[i] = complex(float64(frame[i])/32768*w, 0)
	}
	fft(buf)
	out := make([]float64, BandCount)
	lo, hi := 80.0, 7000.0
	binHz := float64(SampleRate) / float64(n)
	for b := 0; b < BandCount; b++ {
		f0 := lo * math.Pow(hi/lo, float64(b)/BandCount)
		f1 := lo * math.Pow(hi/lo, float64(b+1)/BandCount)
		i0 := int(f0 / binHz)
		i1 := int(f1 / binHz)
		if i1 <= i0 {
			i1 = i0 + 1
		}
		var peak float64
		for i := i0; i < i1 && i < n/2; i++ {
			if m := cmplx.Abs(buf[i]); m > peak {
				peak = m
			}
		}
		// Hann window + n/2 scaling: a full-scale sine peaks near n/4.
		db := 20 * math.Log10(peak/(float64(n)/4)+1e-9)
		out[b] = math.Round(clamp01((db+70)/60)*1000) / 1000
	}
	return out
}

// fft is an in-place radix-2 Cooley-Tukey transform; len(a) must be a
// power of two.
func fft(a []complex128) {
	n := len(a)
	for i, j := 1, 0; i < n; i++ {
		bit := n >> 1
		for ; j&bit != 0; bit >>= 1 {
			j ^= bit
		}
		j ^= bit
		if i < j {
			a[i], a[j] = a[j], a[i]
		}
	}
	for size := 2; size <= n; size <<= 1 {
		step := cmplx.Exp(complex(0, -2*math.Pi/float64(size)))
		for start := 0; start < n; start += size {
			w := complex(1, 0)
			for k := 0; k < size/2; k++ {
				u := a[start+k]
				v := a[start+k+size/2] * w
				a[start+k] = u + v
				a[start+k+size/2] = u - v
				w *= step
			}
		}
	}
}

func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}
