package main

import "testing"

// TestViewsRender exercises every screen's View so a render-time panic or an
// empty output fails the build rather than only appearing at runtime.
func TestViewsRender(t *testing.T) {
	cfg, err := loadConfig("..")
	if err != nil {
		t.Skipf("config not loadable from repo root: %v", err)
	}

	m := initialModel(cfg, "..", "arch")
	m.width = 100
	m.height = 30

	if got := m.viewWelcome(); got == "" {
		t.Error("welcome view empty")
	}

	m.screen = screenAction
	if got := m.View(); got.Content == "" {
		t.Error("action view empty")
	}

	m.screen = screenOptional
	if got := m.View(); got.Content == "" {
		t.Error("optional view empty")
	}

	m.screen = screenSudo
	m.sudoError = "Incorrect password, please try again. (1/3)"
	if got := m.View(); got.Content == "" {
		t.Error("sudo view empty")
	}

	m.screen = screenConfigure
	m.menuStack = []menuFrame{{title: "CONFIGURATION", items: cfg.Menu.Menu, cursor: 0}}
	if got := m.View(); got.Content == "" {
		t.Error("configure view empty")
	}

	m.screen = screenReview
	if got := m.View(); got.Content == "" {
		t.Error("review view empty")
	}

	m.screen = screenInstall
	m.install = &installState{statuses: make([]string, len(cfg.Manifest.Steps)), logPath: "/tmp/caelestia-test.log"}
	for i := range m.install.statuses {
		m.install.statuses[i] = statusPending
	}
	if got := m.View(); got.Content == "" {
		t.Error("install view empty")
	}

	m.install.dialog = true
	m.install.detail = []string{"some error line"}
	if got := m.View(); got.Content == "" {
		t.Error("error dialog view empty")
	}

	m.screen = screenLog
	m.logView = &logState{logPath: "/tmp/caelestia-test.log", lines: []string{"line one", "[WARN] warning", "[ERR] error"}, follow: true}
	if got := m.View(); got.Content == "" {
		t.Error("log view empty")
	}

	m.screen = screenComplete
	m.complete = &completeState{logPath: "/tmp/caelestia-test.log", startEpoch: 12345, failedPkgs: []string{"pkg-a"}, shellFailed: true}
	if got := m.View(); got.Content == "" {
		t.Error("complete view empty")
	}
}
