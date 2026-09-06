package main

// Status vocabulary shared by the progress, review, and complete screens.
// See CONTEXT.md (Installer) and installer/steps.json.
const (
	statusPending = "PENDING"
	statusRunning = "RUNNING"
	statusOK      = "OK"
	statusWarn    = "WARN"
	statusFailed  = "FAILED"
	statusSkipped = "SKIPPED"
	statusIgnored = "IGNORED"
)

func statusGlyph(glyphs map[string]string, status string) string {
	switch status {
	case statusRunning:
		return glyphs["running"]
	case statusOK:
		return glyphs["ok"]
	case statusWarn:
		return glyphs["warn"]
	case statusFailed:
		return glyphs["failed"]
	case statusSkipped:
		return glyphs["skipped"]
	case statusIgnored:
		return "[IGNORED]"
	default:
		return glyphs["pending"]
	}
}

func statusColorName(status string) string {
	switch status {
	case statusRunning:
		return "primary"
	case statusOK:
		return "success"
	case statusWarn:
		return "warning"
	case statusFailed:
		return "error"
	case statusIgnored:
		return "warning"
	default:
		return "muted"
	}
}

// stepIsSkipped mirrors Runner::step_is_skipped in the C++ installer.
func stepIsSkipped(step Step, answers map[string]string) bool {
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

// phaseRollup aggregates a phase's step statuses into a single status.
func phaseRollup(phaseID string, steps []Step, statuses []string) string {
	var failed, running, pending, warn, ignored bool
	allSkipped := true
	for i, st := range steps {
		if st.Phase != phaseID {
			continue
		}
		switch statuses[i] {
		case statusFailed:
			failed = true
		case statusRunning:
			running = true
		case statusPending:
			pending = true
		case statusWarn:
			warn = true
		case statusIgnored:
			ignored = true
		}
		if statuses[i] != statusSkipped {
			allSkipped = false
		}
	}
	switch {
	case failed:
		return statusFailed
	case running:
		return statusRunning
	case pending:
		return statusPending
	case warn:
		return statusWarn
	case ignored:
		return statusIgnored
	case allSkipped:
		return statusSkipped
	default:
		return statusOK
	}
}

// seedMenuDefaults fills answers with item defaults, leaving existing answers alone.
func seedMenuDefaults(items []MenuItem, answers map[string]string) {
	for i := range items {
		item := &items[i]
		if item.Type == "submenu" {
			seedMenuDefaults(item.Items, answers)
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

// enableOptionalApps turns on every boolean in the Applications submenu.
func enableOptionalApps(menu Menu, answers map[string]string) {
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
