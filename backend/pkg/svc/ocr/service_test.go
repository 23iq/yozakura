package ocr

import (
	"reflect"
	"testing"
)

func TestMissingLangs(t *testing.T) {
	listed := "List of available languages in \"/usr/share/tessdata/\" (3):\neng\nosd\nspa\n"
	if got := MissingLangs("eng+spa", listed); got != nil {
		t.Fatalf("got %v", got)
	}
	if got := MissingLangs("eng+rus+jpn", listed); !reflect.DeepEqual(got, []string{"rus", "jpn"}) {
		t.Fatalf("got %v", got)
	}
}
