package uninstall

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
	if got := m.View(); got.Content == "" {
		t.Error("uninstall view empty")
	}
}

func TestFormatBackupLabel(t *testing.T) {
	if got := formatBackupLabel("20260101_120000"); got != "2026-01-01 12:00:00" {
		t.Errorf("formatBackupLabel = %q", got)
	}
	if got := formatBackupLabel("not-a-date"); got != "not-a-date" {
		t.Errorf("formatBackupLabel passthrough = %q", got)
	}
}
