package main

import "testing"

func TestStepIsSkipped(t *testing.T) {
	steps := StepsManifest{
		Steps: []Step{
			{Name: "Update system", Script: "scripts/00a-system-update.sh", Phase: "prepare"},
			{Name: "Install optional components", Script: "scripts/11-optional-apps.sh", Phase: "finalize"},
			{Name: "Install packages", Script: "scripts/02-all-packages.sh", Phase: "packages"},
		},
	}

	answers := map[string]string{
		"SKIP_SYSTEM_UPDATE": "true",
		"INSTALL_VSCODE":     "false",
	}

	if !stepIsSkipped(steps.Steps[0], answers) {
		t.Error("Update system should be skipped when SKIP_SYSTEM_UPDATE is true")
	}
	if !stepIsSkipped(steps.Steps[1], answers) {
		t.Error("optional components should be skipped when no optional app is enabled")
	}
	if stepIsSkipped(steps.Steps[2], answers) {
		t.Error("Install packages should never be skipped")
	}

	answers["INSTALL_ZED"] = "true"
	if stepIsSkipped(steps.Steps[1], answers) {
		t.Error("optional components should run when any optional app is enabled")
	}
}

func TestPhaseRollup(t *testing.T) {
	manifest := StepsManifest{
		Phases: []Phase{{ID: "prepare", Name: "Prepare"}, {ID: "build", Name: "Build"}},
		Steps: []Step{
			{Name: "a", Script: "a.sh", Phase: "prepare"},
			{Name: "b", Script: "b.sh", Phase: "prepare"},
			{Name: "c", Script: "c.sh", Phase: "build"},
		},
	}

	statuses := []string{statusOK, statusPending, statusSkipped}
	if got := phaseRollup("prepare", manifest.Steps, statuses); got != statusPending {
		t.Errorf("prepare rollup = %s, want %s", got, statusPending)
	}
	if got := phaseRollup("build", manifest.Steps, statuses); got != statusSkipped {
		t.Errorf("build rollup = %s, want %s", got, statusSkipped)
	}

	statuses = []string{statusOK, statusWarn, statusFailed}
	if got := phaseRollup("prepare", manifest.Steps, statuses); got != statusWarn {
		t.Errorf("prepare rollup = %s, want %s", got, statusWarn)
	}
	if got := phaseRollup("build", manifest.Steps, statuses); got != statusFailed {
		t.Errorf("build rollup = %s, want %s", got, statusFailed)
	}
}

func TestStatusGlyph(t *testing.T) {
	g := defaultGlyphs()
	if got := statusGlyph(g, statusOK); got != "[OK]" {
		t.Errorf("OK glyph = %q", got)
	}
	if got := statusGlyph(g, statusIgnored); got != "[IGNORED]" {
		t.Errorf("IGNORED glyph = %q", got)
	}
}

func TestSeedMenuDefaults(t *testing.T) {
	menu := Menu{Menu: []MenuItem{
		{ID: "menu_packages", Type: "submenu", Items: []MenuItem{
			{ID: "INSTALL_FISH", Type: "boolean", Default: true},
			{ID: "INSTALL_THUNAR", Type: "boolean", Default: false},
		}},
		{ID: "DEFAULT_SHELL", Type: "select", Default: "fish"},
	}}

	answers := map[string]string{"INSTALL_FISH": "false"}
	seedMenuDefaults(menu.Menu, answers)

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
	menu := Menu{Menu: []MenuItem{
		{ID: "menu_apps", Type: "submenu", Items: []MenuItem{
			{ID: "INSTALL_VSCODE", Type: "boolean"},
			{ID: "INSTALL_ZED", Type: "boolean"},
		}},
		{ID: "menu_packages", Type: "submenu", Items: []MenuItem{
			{ID: "INSTALL_FISH", Type: "boolean"},
		}},
	}}

	answers := map[string]string{}
	enableOptionalApps(menu, answers)

	if answers["INSTALL_VSCODE"] != "true" || answers["INSTALL_ZED"] != "true" {
		t.Error("optional app booleans should be enabled")
	}
	if _, ok := answers["INSTALL_FISH"]; ok {
		t.Error("non-optional menus should not be touched")
	}
}
