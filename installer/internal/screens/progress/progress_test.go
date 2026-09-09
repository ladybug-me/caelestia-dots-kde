package progress

import (
	"testing"
	"time"

	bprogress "charm.land/bubbles/v2/progress"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/manifest"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/theme"
)

func testContext(t *testing.T) *app.Context {
	t.Helper()
	cfg, err := config.Load("../../../..")
	if err != nil {
		t.Skipf("config not loadable from repo root: %v", err)
	}
	return &app.Context{
		Cfg:        cfg,
		Theme:      theme.New(cfg, true),
		Answers:    map[string]string{},
		BundleDir:  "../../../..",
		BaseDistro: "arch",
		Width:      100,
		Height:     30,
	}
}

// TestViewRenders builds a Model directly (bypassing New, which mutates real
// process env vars and creates cache directories) to keep this a pure
// rendering smoke test.
func TestViewRenders(t *testing.T) {
	ctx := testContext(t)
	statuses := make([]string, len(ctx.Cfg.Manifest.Steps))
	for i := range statuses {
		statuses[i] = manifest.StatusPending
	}
	m := &Model{
		ctx:       ctx,
		statuses:  statuses,
		logPath:   "/tmp/caelestia-test.log",
		startTime: time.Now(),
		stepStart: time.Now(),
		bar:       bprogress.New(),
	}
	if got := m.View(); got.Content == "" {
		t.Error("progress view empty")
	}

	m.dialog = true
	m.detail = []string{"some error line"}
	if got := m.View(); got.Content == "" {
		t.Error("error dialog view empty")
	}
}
