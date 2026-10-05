package voice

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Non-speech annotations whisper emits for silence/noise: [BLANK_AUDIO],
// (music), *coughs*, ♪ ... ♪.
var annotationRe = regexp.MustCompile(`\[[^\]]*\]|\([^)]*\)|\*[^*]*\*|♪[^♪]*♪?`)

// Well-known whisper hallucinations on near-silent input (subtitle
// credits from its training data). Only dropped when they are the whole
// transcript.
var hallucinations = []string{
	"thank you.", "thanks for watching!", "thank you for watching.",
	"субтитры сделал dimatorzok", "субтитры создавал dimatorzok",
	"продолжение следует...", "редактор субтитров а.семкин корректор а.егорова",
	"ご視聴ありがとうございました", "チャンネル登録よろしくお願いします",
}

// CleanTranscript collapses whitespace and strips non-speech annotations
// and whole-transcript hallucinations.
func CleanTranscript(s string) string {
	s = annotationRe.ReplaceAllString(s, " ")
	s = strings.Join(strings.Fields(s), " ")
	low := strings.ToLower(s)
	for _, h := range hallucinations {
		if low == h {
			return ""
		}
	}
	return s
}

// FormatDictation applies the dictation options: punctuation=false strips
// sentence punctuation and the leading capital; trailingSpace appends a
// space so consecutive dictations join naturally.
func FormatDictation(s string, punctuation, trailingSpace bool) string {
	if s == "" {
		return ""
	}
	if !punctuation {
		s = strings.Map(func(r rune) rune {
			switch r {
			case '.', ',', '!', '?', ';', ':', '。', '、', '！', '？', '…':
				return -1
			}
			return r
		}, s)
		s = strings.Join(strings.Fields(s), " ")
		if r, n := utf8.DecodeRuneInString(s); n > 0 && unicode.IsUpper(r) {
			rest := s[n:]
			r2, _ := utf8.DecodeRuneInString(rest)
			// Keep acronyms ("NASA") and the English "I" / "I'm".
			pronounI := r == 'I' && (rest == "" || r2 == ' ' || r2 == '\'' || r2 == '’')
			if !unicode.IsUpper(r2) && !pronounI {
				s = string(unicode.ToLower(r)) + rest
			}
		}
	}
	if trailingSpace && s != "" {
		s += " "
	}
	return s
}

var langCodes = map[string]string{
	"english": "en", "russian": "ru", "japanese": "ja", "spanish": "es",
	"german": "de", "french": "fr", "chinese": "zh", "korean": "ko",
	"ukrainian": "uk", "italian": "it", "portuguese": "pt", "polish": "pl",
	"dutch": "nl", "turkish": "tr", "arabic": "ar", "hindi": "hi",
	"czech": "cs", "swedish": "sv", "finnish": "fi", "greek": "el",
	"hebrew": "he", "vietnamese": "vi", "indonesian": "id", "thai": "th",
	"belarusian": "be", "kazakh": "kk", "romanian": "ro", "hungarian": "hu",
	"danish": "da", "norwegian": "no", "bulgarian": "bg", "serbian": "sr",
}

// LangCode maps whisper's full language name ("russian") to its code.
// Codes pass through; unknown names yield "".
func LangCode(name string) string {
	n := strings.ToLower(strings.TrimSpace(name))
	if c, ok := langCodes[n]; ok {
		return c
	}
	if len(n) == 2 {
		return n
	}
	return ""
}
