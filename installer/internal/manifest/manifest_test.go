package manifest

import (
	"testing"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
)

func TestStepIsSkipped(t *testing.T) {
	steps := []config.Step{
		{Name: "Update system", Script: "scripts/00a-system-update.sh", Phase: "prepare"},
		{Name: "Install optional components", Script: "scripts/11-optional-apps.sh", Phase: "finalize"},
		{Name: "Install packages", Script: "scripts/02-all-packages.sh", Phase: "packages"},
	}

	answers := map[string]string{
		"SKIP_SYSTEM_UPDATE": "true",
		"INSTALL_VSCODE":     "false",
	}

	if !StepIsSkipped(steps[0], answers) {
		t.Error("Update system should be skipped when SKIP_SYSTEM_UPDATE is true")
	}
	if !StepIsSkipped(steps[1], answers) {
		t.Error("optional components should be skipped when no optional app is enabled")
	}
	if StepIsSkipped(steps[2], answers) {
		t.Error("Install packages should never be skipped")
	}

	answers["INSTALL_ZED"] = "true"
	if StepIsSkipped(steps[1], answers) {
		t.Error("optional components should run when any optional app is enabled")
	}
}

func TestPhaseRollup(t *testing.T) {
	steps := []config.Step{
		{Name: "a", Script: "a.sh", Phase: "prepare"},
		{Name: "b", Script: "b.sh", Phase: "prepare"},
		{Name: "c", Script: "c.sh", Phase: "build"},
	}

	statuses := []string{StatusOK, StatusPending, StatusSkipped}
	if got := PhaseRollup("prepare", steps, statuses); got != StatusPending {
		t.Errorf("prepare rollup = %s, want %s", got, StatusPending)
	}
	if got := PhaseRollup("build", steps, statuses); got != StatusSkipped {
		t.Errorf("build rollup = %s, want %s", got, StatusSkipped)
	}

	statuses = []string{StatusOK, StatusWarn, StatusFailed}
	if got := PhaseRollup("prepare", steps, statuses); got != StatusWarn {
		t.Errorf("prepare rollup = %s, want %s", got, StatusWarn)
	}
	if got := PhaseRollup("build", steps, statuses); got != StatusFailed {
		t.Errorf("build rollup = %s, want %s", got, StatusFailed)
	}
}

func TestStatusGlyph(t *testing.T) {
	g := config.DefaultGlyphs()
	if got := Glyph(g, StatusOK); got != "[OK]" {
		t.Errorf("OK glyph = %q", got)
	}
	if got := Glyph(g, StatusIgnored); got != "[IGNORED]" {
		t.Errorf("IGNORED glyph = %q", got)
	}
}

func TestSeedMenuDefaults(t *testing.T) {
	items := []config.MenuItem{
		{ID: "menu_packages", Type: "submenu", Items: []config.MenuItem{
			{ID: "INSTALL_FISH", Type: "boolean", Default: true},
			{ID: "INSTALL_THUNAR", Type: "boolean", Default: false},
		}},
		{ID: "DEFAULT_SHELL", Type: "select", Default: "fish"},
	}

	answers := map[string]string{"INSTALL_FISH": "false"}
	SeedMenuDefaults(items, answers)

	if answers["INSTALL_FISH"] != "false" {
		t.Error("existing answer should not be overwritten")
	}
	if answers["INSTALL_THUNAR"] != "false" {
		t.Errorf("INSTALL_THUNAR default = %q, want false", answers["INSTALL_THUNAR"])
	}
	if answers["DEFAULT_SHELL"] != "fish" {
		t.Errorf("DEFAULT_SHELL default = %q, want fish", answers["DEFAULT_SHELL"])
	}
}

func TestEnableOptionalApps(t *testing.T) {
	menu := config.Menu{Menu: []config.MenuItem{
		{ID: "menu_apps", Type: "submenu", Items: []config.MenuItem{
			{ID: "INSTALL_VSCODE", Type: "boolean"},
			{ID: "INSTALL_ZED", Type: "boolean"},
		}},
		{ID: "menu_packages", Type: "submenu", Items: []config.MenuItem{
			{ID: "INSTALL_FISH", Type: "boolean"},
		}},
	}}

	answers := map[string]string{}
	EnableOptionalApps(menu, answers)

	if answers["INSTALL_VSCODE"] != "true" || answers["INSTALL_ZED"] != "true" {
		t.Error("optional app booleans should be enabled")
	}
	if _, ok := answers["INSTALL_FISH"]; ok {
		t.Error("non-optional menus should not be touched")
	}
}
