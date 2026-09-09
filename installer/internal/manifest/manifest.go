// Package manifest holds the status vocabulary and step/phase rollup logic
// shared by the review, progress, and complete screens. See CONTEXT.md
// (Installer) and installer/steps.json.
package manifest

import "github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"

// Status values a step (and, by rollup, a phase) can be in. Each constant IS
// its own display tag - no separate glyph/icon lookup - keeping status
// rendering to plain ASCII text plus color (see internal/theme.StatusText).
const (
	StatusPending = "PENDING"
	StatusRunning = "RUNNING"
	StatusOK      = "OK"
	StatusWarn    = "WARN"
	StatusFailed  = "FAILED"
	StatusSkipped = "SKIPPED"
	StatusIgnored = "IGNORED"
)

// ColorName returns the theme palette entry a status should render with.
func ColorName(status string) string {
	switch status {
	case StatusRunning:
		return "primary"
	case StatusOK:
		return "success"
	case StatusWarn:
		return "warning"
	case StatusFailed:
		return "error"
	case StatusIgnored:
		return "warning"
	default:
		return "muted"
	}
}

// StepIsSkipped mirrors Runner::step_is_skipped in the C++ installer.
func StepIsSkipped(step config.Step, answers map[string]string) bool {
	if step.Name == "Update system" {
		return answers["SKIP_SYSTEM_UPDATE"] == "true"
	}
	if step.Name == "Install optional components" {
		for _, id := range []string{
			"INSTALL_VSCODE", "INSTALL_ZED", "INSTALL_SPICETIFY",
			"INSTALL_DISCORD", "INSTALL_TODOIST", "INSTALL_FIREFOX_THEME",
		} {
			if answers[id] == "true" {
				return false
			}
		}
		return true
	}
	return false
}

// PhaseRollup aggregates a phase's step statuses into a single status.
func PhaseRollup(phaseID string, steps []config.Step, statuses []string) string {
	var failed, running, pending, warn, ignored bool
	allSkipped := true
	for i, st := range steps {
		if st.Phase != phaseID {
			continue
		}
		switch statuses[i] {
		case StatusFailed:
			failed = true
		case StatusRunning:
			running = true
		case StatusPending:
			pending = true
		case StatusWarn:
			warn = true
		case StatusIgnored:
			ignored = true
		}
		if statuses[i] != StatusSkipped {
			allSkipped = false
		}
	}
	switch {
	case failed:
		return StatusFailed
	case running:
		return StatusRunning
	case pending:
		return StatusPending
	case warn:
		return StatusWarn
	case ignored:
		return StatusIgnored
	case allSkipped:
		return StatusSkipped
	default:
		return StatusOK
	}
}

// SeedMenuDefaults fills answers with item defaults, leaving existing answers alone.
func SeedMenuDefaults(items []config.MenuItem, answers map[string]string) {
	for i := range items {
		item := &items[i]
		if item.Type == "submenu" {
			SeedMenuDefaults(item.Items, answers)
			continue
		}
		if item.ID == "" {
			continue
		}
		if _, ok := answers[item.ID]; ok {
			continue
		}
		switch v := item.Default.(type) {
		case bool:
			if v {
				answers[item.ID] = "true"
			} else {
				answers[item.ID] = "false"
			}
		case string:
			answers[item.ID] = v
		}
	}
}

// EnableOptionalApps turns on every boolean in the Applications submenu.
func EnableOptionalApps(menu config.Menu, answers map[string]string) {
	for i := range menu.Menu {
		item := &menu.Menu[i]
		if item.Type == "submenu" && item.ID == "menu_apps" {
			for j := range item.Items {
				child := &item.Items[j]
				if child.Type == "boolean" && child.ID != "" {
					answers[child.ID] = "true"
				}
			}
		}
	}
}
