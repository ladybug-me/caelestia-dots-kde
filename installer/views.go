package main

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
)

var spinnerFrames = []string{"|", "/", "-", "\\"}

func (u ui) accentText(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("accent")).Render(s)
}

func (u ui) errorText(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("error")).Render(s)
}

func (u ui) warningText(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("warning")).Render(s)
}

func (u ui) successText(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("success")).Render(s)
}

func (m model) View() string {
	switch m.screen {
	case screenWelcome:
		return m.viewWelcome()
	case screenAction:
		return m.viewAction()
	case screenOptional:
		return m.viewOptional()
	case screenSudo:
		return m.viewSudo()
	case screenConfigure:
		return m.viewConfigure()
	case screenReview:
		return m.viewReview()
	case screenInstall:
		return m.viewInstall()
	case screenLog:
		return m.viewLog()
	case screenComplete:
		return m.viewComplete()
	}
	return ""
}

func (m model) viewWelcome() string {
	art := m.cfg.Theme.Splash.Art
	if len(art) == 0 {
		art = []string{"Caelestia Installer"}
	}
	artColor := m.cfg.Theme.Splash.ArtColor
	if artColor == "" {
		artColor = "accent"
	}
	author := m.cfg.Theme.Splash.Author
	if author == "" {
		author = "By @ladybug-me"
	}
	co := m.cfg.Theme.Splash.CoAuthor
	if co == "" {
		co = "Co-maintainer: 0xSolanaceae"
	}

	accent := lipgloss.NewStyle().Foreground(m.ui.c(artColor))
	artLines := make([]string, 0, len(art))
	for _, l := range art {
		artLines = append(artLines, accent.Render(l))
	}

	lines := []string{
		lipgloss.JoinVertical(lipgloss.Center, artLines...),
		m.ui.muted(author),
		m.ui.muted(co),
		"",
		m.ui.title("Caelestia KDE installer"),
		"",
		m.ui.secondary("Detected distribution: " + distroLabel(m.baseDistro)),
		"",
		m.ui.muted("Press Enter to continue (Esc to quit)"),
	}
	return lipgloss.JoinVertical(lipgloss.Center, lines...)
}

func (m model) viewAction() string {
	lines := []string{m.ui.muted("Up/Down navigate  Enter select  Left/Esc back")}
	for i, a := range m.actions {
		prefix := "  "
		if i == m.actionCursor {
			prefix = "> "
		}
		text := prefix + a.title
		if i == m.actionCursor {
			lines = append(lines, m.ui.selected(text))
		} else {
			lines = append(lines, m.ui.normal(text))
		}
	}
	if m.actionCursor < len(m.actions) {
		lines = append(lines, "", m.ui.secondary(fit(m.actions[m.actionCursor].help, m.width-8)))
	}
	return m.renderScreen("CAELESTIA SETUP", "Esc - Exit", lines)
}

func (m model) viewOptional() string {
	choices := []string{
		"Yes - also theme my applications",
		"No - keep the standard install",
	}
	helps := []string{
		"Adds theming for VSCode/VSCodium, Zed, Spicetify, Discord/Equibop, Todoist, and Firefox.",
		"Installs the shell, packages, and theming only.",
	}
	lines := []string{
		m.ui.muted("Up/Down navigate  Enter select  Left/Esc back"),
		"",
		m.ui.normal("Caelestia can also theme your applications."),
		m.ui.normal("Install the optional app theming as well?"),
		"",
	}
	for i := range choices {
		prefix := "  "
		if i == m.optionalCursor {
			prefix = "> "
		}
		text := prefix + choices[i]
		if i == m.optionalCursor {
			lines = append(lines, m.ui.selected(text))
		} else {
			lines = append(lines, m.ui.normal(text))
		}
	}
	lines = append(lines, "", m.ui.secondary(fit(helps[m.optionalCursor], m.width-8)))
	return m.renderScreen("OPTIONAL APP THEMING", "Esc - Cancel installation", lines)
}

func (m model) viewSudo() string {
	lines := []string{
		m.ui.normal("Root privileges are required to install packages."),
		"",
		"Password: " + m.password.View(),
	}
	if m.sudoError != "" {
		lines = append(lines, "", m.ui.errorText(m.sudoError))
	}
	return m.renderScreen("PRIVILEGE ESCALATION", "Esc - Cancel", lines)
}

func menuDisplay(item MenuItem, answers map[string]string, glyphs map[string]string) string {
	switch item.Type {
	case "submenu":
		return item.Title + " >"
	case "boolean":
		g := glyphs["checkbox_off"]
		if answers[item.ID] == "true" {
			g = glyphs["checkbox_on"]
		}
		return g + " " + item.Title
	case "select":
		return item.Title + ": " + glyphs["select_left"] + " " + answers[item.ID] + " " + glyphs["select_right"]
	default:
		return item.Title
	}
}

func (m model) viewConfigure() string {
	if len(m.menuStack) == 0 {
		return ""
	}
	frame := m.menuStack[len(m.menuStack)-1]
	lines := []string{m.ui.muted("Up/Down navigate  Enter select  Left/Esc back")}
	for i := range frame.items {
		item := frame.items[i]
		text := menuDisplay(item, m.answers, m.cfg.Glyphs)
		prefix := "  "
		if i == frame.cursor {
			prefix = "> "
		}
		if i == frame.cursor {
			lines = append(lines, m.ui.selected(prefix+text))
		} else {
			lines = append(lines, m.ui.normal(prefix+text))
		}
	}
	footer := ""
	if frame.cursor < len(frame.items) {
		footer = fit(frame.items[frame.cursor].Help, m.width-4)
	}
	return m.renderScreen(frame.title, footer, lines)
}

func (m model) viewReview() string {
	var all []string
	for _, ph := range m.cfg.Manifest.Phases {
		all = append(all, m.ui.selected(ph.Name))
		for i := range m.cfg.Manifest.Steps {
			st := m.cfg.Manifest.Steps[i]
			if st.Phase != ph.ID {
				continue
			}
			status := statusPending
			if stepIsSkipped(st, m.answers) {
				status = statusSkipped
			}
			glyph := statusGlyph(m.cfg.Glyphs, status)
			if status == statusSkipped {
				all = append(all, m.ui.muted("  "+glyph+" "+st.Name+" (skipped)"))
			} else {
				all = append(all, m.ui.normal("  "+glyph+" "+st.Name))
			}
		}
		all = append(all, "")
	}

	maxRows := m.height - 6
	if maxRows < 1 {
		maxRows = 1
	}
	top := m.reviewScroll
	if top > len(all)-maxRows {
		top = len(all) - maxRows
	}
	if top < 0 {
		top = 0
	}
	lines := visible(all, top, maxRows)

	return m.renderScreen("REVIEW INSTALLATION",
		"Press Enter to begin installation   Esc - go back to configuration", lines)
}

func (m model) viewInstall() string {
	if m.install == nil {
		return ""
	}
	if m.install.dialog {
		return m.viewErrorDialog()
	}

	ins := m.install
	steps := m.cfg.Manifest.Steps

	var all []string
	focus := 0
	all = append(all, m.ui.normal(m.progressBar()))

	for _, ph := range m.cfg.Manifest.Phases {
		ps := phaseRollup(ph.ID, steps, ins.statuses)
		all = append(all, m.ui.statusText(ps, statusGlyph(m.cfg.Glyphs, ps)+" "+ph.Name))
		for i := range steps {
			if steps[i].Phase != ph.ID {
				continue
			}
			status := ins.statuses[i]
			text := "  " + statusGlyph(m.cfg.Glyphs, status) + " " + steps[i].Name
			if i == ins.current && status == statusRunning {
				focus = len(all)
				text = "  " + spinnerFrames[ins.spinner%len(spinnerFrames)] + " " + steps[i].Name
				all = append(all, m.ui.selected(text))
			} else {
				all = append(all, m.ui.statusText(status, text))
			}
		}
	}

	maxRows := m.height - 6
	if maxRows < 1 {
		maxRows = 1
	}
	top := 0
	if len(all) > maxRows {
		top = focus - maxRows/2
		if top < 0 {
			top = 0
		}
		if top > len(all)-maxRows {
			top = len(all) - maxRows
		}
	}
	lines := visible(all, top, maxRows)

	return m.renderScreen("INSTALLING", "L - Full log    Ctrl+C - Cancel", lines)
}

func (m model) progressBar() string {
	total := len(m.cfg.Manifest.Steps)
	current := m.install.current
	if current > total {
		current = total
	}
	barW := m.width - 12
	if barW < 6 {
		barW = 6
	}
	done := 0
	if total > 0 {
		done = current * barW / total
	}
	if done > barW {
		done = barW
	}
	arrow := 0
	if done < barW {
		arrow = 1
	}
	bar := strings.Repeat("=", done)
	if arrow == 1 {
		bar += ">"
	}
	bar += strings.Repeat(" ", barW-done-arrow)
	return "[" + bar + "] " + fmt.Sprintf("%d/%d", current, total)
}

func (m model) viewErrorDialog() string {
	ins := m.install
	step := m.cfg.Manifest.Steps[ins.current]
	lines := []string{
		m.ui.errorText("Step failed: " + step.Name),
		m.ui.normal("Script: " + step.Script),
		m.ui.errorText("Last output:"),
	}
	for _, l := range ins.detail {
		lines = append(lines, m.ui.normal(fit(l, m.width-6)))
	}
	opts := []string{"Retry", "Ignore", "Exit"}
	parts := make([]string, 0, 3)
	for i, o := range opts {
		prefix := "  "
		if i == ins.errCursor {
			prefix = "> "
		}
		if i == ins.errCursor {
			parts = append(parts, m.ui.selected(prefix+o))
		} else {
			parts = append(parts, m.ui.normal(prefix+o))
		}
	}
	lines = append(lines, "", strings.Join(parts, "    "))
	return m.renderScreen("INSTALLATION ERROR", "", lines)
}

func (m model) viewComplete() string {
	c := m.complete
	hasErrors := len(c.failedPkgs) > 0 || c.shellFailed
	title := "INSTALLATION COMPLETE"
	if hasErrors {
		title = "INSTALLATION COMPLETED WITH WARNINGS"
	}

	var lines []string
	if c.startEpoch > 0 {
		elapsed := time.Now().Unix() - c.startEpoch
		hours := elapsed / 3600
		mins := (elapsed % 3600) / 60
		secs := elapsed % 60
		lines = append(lines, m.ui.successText(fmt.Sprintf("%s Finished in %dh %dm %ds",
			m.cfg.Glyphs["ok"], hours, mins, secs)))
	}

	if hasErrors {
		lines = append(lines, "", m.ui.errorText("ATTENTION NEEDED"))
		if c.shellFailed {
			lines = append(lines, m.ui.errorText("- Shell build failed (check missing dependencies in log)."))
		}
		if len(c.failedPkgs) > 0 {
			lines = append(lines, m.ui.errorText("- Failed packages: "+strings.Join(c.failedPkgs, ", ")))
		}
	}

	lines = append(lines, "", m.ui.selected("QUICK START & SHORTCUTS"))
	for _, s := range []string{
		"Super / Super+Space   Application Launcher",
		"Super+Return          Terminal",
		"Super+/               Show Keybinds Helper",
		"Super+V               Clipboard History",
		"Super+Shift+S         Screenshot Tool",
		"Super+B               Sidebar & Notifications",
	} {
		lines = append(lines, m.ui.normal("  "+s))
	}

	lines = append(lines, "", m.ui.selected("NEXT STEPS"))
	lines = append(lines, m.ui.normal("- Log out and back in to start your new Caelestia session."))
	lines = append(lines, m.ui.muted("- Full log saved to: "+c.logPath))

	return m.renderScreen(title, "Press L to view the full log   Log out now? (Y/n)", lines)
}

func (m model) viewLog() string {
	lv := m.logView
	if lv == nil {
		return ""
	}
	show := m.height - 6
	if show < 1 {
		show = 1
	}
	maxScroll := len(lv.lines) - show
	if maxScroll < 0 {
		maxScroll = 0
	}
	if lv.follow {
		lv.viewTop = maxScroll
	} else {
		if lv.viewTop > maxScroll {
			lv.viewTop = maxScroll
		}
		if lv.viewTop < 0 {
			lv.viewTop = 0
		}
	}

	var lines []string
	for i := 0; i < show && lv.viewTop+i < len(lv.lines); i++ {
		l := lv.lines[lv.viewTop+i]
		text := fit(l, m.width-6)
		switch {
		case strings.Contains(l, "[ERR]"):
			lines = append(lines, m.ui.errorText(text))
		case strings.Contains(l, "[WARN]"):
			lines = append(lines, m.ui.warningText(text))
		default:
			lines = append(lines, m.ui.normal(text))
		}
	}

	status := "Following"
	if !lv.follow {
		status = "Paused"
	}
	footer := status + "    Up/Down/PgUp/PgDn scroll   n/p - next issue   L - back"
	return m.renderScreen("INSTALL LOG", footer, lines)
}

func visible(lines []string, top, maxRows int) []string {
	if top < 0 {
		top = 0
	}
	if maxRows < 1 {
		maxRows = 1
	}
	if top > len(lines)-maxRows {
		top = len(lines) - maxRows
	}
	if top < 0 {
		top = 0
	}
	if top >= len(lines) {
		return nil
	}
	end := top + maxRows
	if end > len(lines) {
		end = len(lines)
	}
	return lines[top:end]
}
