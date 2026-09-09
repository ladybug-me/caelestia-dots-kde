package complete

import (
	"testing"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
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

func TestViewRenders(t *testing.T) {
	ctx := testContext(t)
	m := New(ctx)
	m.startEpoch = 12345
	m.failedPkgs = []string{"pkg-a"}
	m.shellFailed = true
	if got := m.View(); got.Content == "" {
		t.Error("complete view empty")
	}
}
