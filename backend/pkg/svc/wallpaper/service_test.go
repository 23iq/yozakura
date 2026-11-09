package wallpaper

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/videoproxy"
)

func TestVideoProxyAnswersOriginalForBadRequests(t *testing.T) {
	s := NewService(context.Background(), t.TempDir())
	for _, params := range []string{`{"path":"relative.mp4","width":1920,"height":1080}`, `{"path":"/nope/x.mp4"}`, ``} {
		got, err := s.videoProxy(json.RawMessage(params))
		assert.NoError(t, err, params)
		res, ok := got.(videoproxy.Result)
		if assert.True(t, ok, params) {
			assert.Equal(t, videoproxy.StateOriginal, res.State, params)
			assert.Empty(t, res.Path, params)
		}
	}
	_, err := s.videoProxy(json.RawMessage(`{"path":`))
	assert.Error(t, err, "malformed params")
}
