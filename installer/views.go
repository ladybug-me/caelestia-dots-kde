package main

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
)

var spinnerFrames = []string{"|", "/", "-", "\\"}

type listOption struct {
	label string
	desc  string
}

func (m model) renderBanner() string {
	art := m.cfg.Theme.Splash.Art
	if len(art) == 0 {
		art = []string{"Caelestia Installer"}
	}
	artColor := m.cfg.Theme.Splash.ArtColor
	if artColor == "" {
		artColor = "accent"
	}
	style := lipgloss.NewStyle().Foreground(m.ui.c(artColor)).Bold(true)
	lines := make([]string, 0, len(art))
	for _, l := range art {
		lines = append(lines, style.Render(l))
	}
	return lipgloss.JoinVertical(lipgloss.Center, lines...)
}

func (m model) renderPageStart(b *strings.Builder, title string) {
	b.WriteString(m.renderBanner())
	b.WriteByte('\n')
	b.WriteString(m.ui.title.Render(title))
	b.WriteString("\n\n")
}

func (m model) renderFooter(b *strings.Builder, parts ...string) {
	b.WriteString(m.ui.subtle.Render("Press "))
	for i, part := range parts {
		if i%2 == 0 {
			b.WriteString(m.ui.key.Render(part))
		} else {
			b.WriteString(m.ui.subtle.Render(part))
		}
	}
}

func (m model) renderOptionList(b *strings.Builder, options []listOption, selected int) {
	width := m.width - 2
	if width < 20 {
		width = 20
	}
	for i, opt := range options {
		if i == selected {
			b.WriteString(m.ui.selectedRow(opt.label, width))
		} else {
			b.WriteString(m.ui.row(opt.label, width))
		}
		b.WriteByte('\n')
		if opt.desc != "" {
			b.WriteString(lipgloss.NewStyle().Foreground(m.ui.c("muted")).Padding(0, 1).Render(opt.desc))
			b.WriteByte('\n')
		}
		if i < len(options)-1 {
			b.WriteByte('\n')
		}
	}
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
	var b strings.Builder
	m.renderPageStart(&b, "Caelestia Installer")

	b.WriteString(m.ui.normal.Render("System: " + distroLabel(m.baseDistro)))
	b.WriteString("\n\n")

	b.WriteString(m.ui.sectionLabel("What you get"))
	b.WriteString("\n\n")

	features := []struct{ tag, desc string }{
		{"[shell]", "Caelestia KDE shell (Quickshell)"},
		{"[packages]", "fish, foot, btop, fastfetch, and more"},
		{"[theme]", "Material You dynamic colors and Darkly"},
		{"[config]", "keybindings, window rules, and autostart"},
	}
	tagStyle := m.ui.accent.Bold(true)
	for _, feat := range features {
		fmt.Fprintf(&b, "  %s %s\n", tagStyle.Render(fmt.Sprintf("%-12s", feat.tag)), m.ui.normal.Render(feat.desc))
	}
	b.WriteByte('\n')

	m.renderFooter(&b, "Enter", " to continue, ", "Esc", " to quit")
	return b.String()
}

func (m model) viewAction() string {
	options := make([]listOption, len(m.actions))
	for i, a := range m.actions {
		options[i] = listOption{label: a.title, desc: a.help}
	}
	var b strings.Builder
	m.renderPageStart(&b, "Setup")
	b.WriteString(m.ui.subtle.Render("System: " + distroLabel(m.baseDistro)))
	b.WriteString("\n\n")
	m.renderOptionList(&b, options, m.actionCursor)
	b.WriteByte('\n')
	m.renderFooter(&b, "↑/↓", " to navigate, ", "Enter", " to select, ", "Esc", " to quit")
	return b.String()
}

func (m model) viewOptional() string {
	options := []listOption{
		{"Yes - also theme my applications", "Adds theming for VSCode/VSCodium, Zed, Spicetify, Discord/Equibop, Todoist, and Firefox."},
		{"No - keep the standard install", "Installs the shell, packages, and theming only."},
	}
	var b strings.Builder
	m.renderPageStart(&b, "Optional App Theming")
	b.WriteString(m.ui.normal.Render("Theme supported applications alongside Caelestia."))
	b.WriteString("\n\n")
	m.renderOptionList(&b, options, m.optionalCursor)
	b.WriteByte('\n')
	m.renderFooter(&b, "↑/↓", " to choose, ", "Enter", " to confirm, ", "Esc", " to cancel installation")
	return b.String()
}

func (m model) viewSudo() string {
	var b strings.Builder
	m.renderPageStart(&b, "Authentication")
	b.WriteString(m.ui.normal.Render("Root privileges are required to install packages."))
	b.WriteString("\n\n")
	b.WriteString(m.ui.subtle.Render("sudo"))
	b.WriteString("\n")
	b.WriteString(m.ui.highlight.Render("Password: ") + m.password.View())
	if m.sudoError != "" {
		b.WriteString("\n\n")
		b.WriteString(m.ui.errorBox.Render(m.sudoError))
	}
	b.WriteString("\n\n")
	m.renderFooter(&b, "Enter", " to verify, ", "Esc", " to cancel")
	return b.String()
}

func (m model) viewConfigure() string {
	if len(m.menuStack) == 0 {
		return ""
	}
	frame := m.menuStack[len(m.menuStack)-1]
	var b strings.Builder
	m.renderPageStart(&b, frame.title)
	b.WriteString(m.ui.subtle.Render("Choose the components to include in this installation."))
	b.WriteString("\n\n")

	options := make([]listOption, len(frame.items))
	for i := range frame.items {
		options[i] = listOption{
			label: menuDisplay(frame.items[i], m.answers, m.cfg.Glyphs),
			desc:  frame.items[i].Help,
		}
	}
	m.renderOptionList(&b, options, frame.cursor)
	b.WriteByte('\n')
	m.renderFooter(&b, "↑/↓", " to navigate, ", "Enter", " to toggle/select, ", "←/Esc", " to go back")
	return b.String()
}

func (m model) viewReview() string {
	var b strings.Builder
	m.renderPageStart(&b, "Review Installation")
	b.WriteString(m.ui.subtle.Render("The following steps will run in order."))
	b.WriteString("\n\n")

	var all []string
	for _, ph := range m.cfg.Manifest.Phases {
		all = append(all, m.ui.sectionLabel(ph.Name))
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
				all = append(all, m.ui.subtle.Render("  "+glyph+" "+st.Name+" (skipped)"))
			} else {
				all = append(all, m.ui.normal.Render("  "+glyph+" "+st.Name))
			}
		}
		all = append(all, "")
	}

	maxRows := m.height - 12
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
	for _, l := range visible(all, top, maxRows) {
		b.WriteString(l)
		b.WriteByte('\n')
	}
	b.WriteByte('\n')
	m.renderFooter(&b, "Enter", " to begin installation, ", "Esc", " to go back")
	return b.String()
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
	var b strings.Builder
	m.renderPageStart(&b, "Installing")

	if len(steps) == 0 || ins.current >= len(steps) {
		b.WriteString(m.ui.success.Render(m.cfg.Glyphs["ok"] + " Installation complete"))
		return b.String()
	}

	cur := steps[ins.current]
	phaseName := cur.Phase
	for _, ph := range m.cfg.Manifest.Phases {
		if ph.ID == cur.Phase {
			phaseName = ph.Name
			break
		}
	}
	spin := spinnerFrames[ins.spinner%len(spinnerFrames)]
	stepLabel := fmt.Sprintf("%s %s", phaseName, cur.Name)
	b.WriteString(m.ui.accent.Render(spin) + m.ui.normal.Render("  "+stepLabel))
	b.WriteString("\n")
	b.WriteString(m.ui.subtle.Render("    " + m.runningTime()))
	b.WriteString("\n\n")
	b.WriteString(ins.progress.View())
	b.WriteByte('\n')
	b.WriteString(m.ui.subtle.Render(fmt.Sprintf("Step %d of %d", ins.current+1, len(steps))))
	b.WriteByte('\n')
	b.WriteString(m.ui.subtle.Render("$ bash " + cur.Script))

	if len(ins.liveLines) > 0 {
		b.WriteString("\n\n")
		b.WriteString(m.ui.sectionLabel("Live output"))
		b.WriteByte('\n')
		shown := ins.liveLines
		if len(shown) > 8 {
			shown = shown[len(shown)-8:]
		}
		for _, l := range shown {
			b.WriteString(m.renderLiveLine(l))
			b.WriteByte('\n')
		}
	}

	b.WriteByte('\n')
	m.renderFooter(&b, "L", " for the full log, ", "Ctrl+C", " to cancel")
	return b.String()
}

// runningTime formats the per-step and overall elapsed time for the hero line.
func (m model) runningTime() string {
	ins := m.install
	if ins == nil || ins.stepStart.IsZero() {
		return ""
	}
	return "step " + formatDuration(time.Since(ins.stepStart)) + "  ·  total " + formatDuration(time.Since(ins.startTime))
}

func formatDuration(d time.Duration) string {
	if d < 0 {
		d = 0
	}
	s := int(d.Seconds())
	h := s / 3600
	min := (s % 3600) / 60
	sec := s % 60
	if h > 0 {
		return fmt.Sprintf("%dh %02dm %02ds", h, min, sec)
	}
	if min > 0 {
		return fmt.Sprintf("%dm %02ds", min, sec)
	}
	return fmt.Sprintf("%ds", sec)
}

func (m model) renderLiveLine(l string) string {
	text := fit(l, m.width-4)
	switch {
	case strings.Contains(l, "[ERR]"):
		return m.ui.error.Padding(0, 1).Render(text)
	case strings.Contains(l, "[WARN]"):
		return m.ui.warning.Padding(0, 1).Render(text)
	default:
		return m.ui.subtle.Padding(0, 1).Render(text)
	}
}

func progressBarWidth(width int) int {
	barW := width - 10
	if barW > 72 {
		barW = 72
	}
	if barW < 12 {
		barW = 12
	}
	return barW
}

func (m model) viewErrorDialog() string {
	ins := m.install
	step := m.cfg.Manifest.Steps[ins.current]
	var b strings.Builder
	m.renderPageStart(&b, "Installation Error")

	lines := []string{
		m.ui.error.Render("Step failed: " + step.Name),
		m.ui.normal.Render("Script: " + step.Script),
		m.ui.subtle.Render("Last output:"),
	}
	for _, l := range ins.detail {
		lines = append(lines, m.ui.normal.Render(fit(l, m.width-6)))
	}
	b.WriteString(m.ui.errorBox.Render(strings.Join(lines, "\n")))
	b.WriteString("\n\n")

	opts := []string{"Retry", "Ignore", "Exit"}
	parts := make([]string, 0, 3)
	for i, o := range opts {
		if i == ins.errCursor {
			parts = append(parts, m.ui.button.Render(o))
		} else {
			parts = append(parts, m.ui.normal.Render("  "+o+"  "))
		}
	}
	b.WriteString(strings.Join(parts, "    "))
	b.WriteByte('\n')
	b.WriteString(m.ui.subtle.Render("Use ") + m.ui.key.Render("←/→") + m.ui.subtle.Render(" to choose, ") + m.ui.key.Render("Enter") + m.ui.subtle.Render(" to confirm"))
	return b.String()
}

func (m model) viewComplete() string {
	c := m.complete
	hasErrors := len(c.failedPkgs) > 0 || c.shellFailed
	title := "Installation Complete"
	if hasErrors {
		title = "Installation Completed With Warnings"
	}

	var b strings.Builder
	m.renderPageStart(&b, title)

	if c.startEpoch > 0 {
		elapsed := time.Now().Unix() - c.startEpoch
		hours := elapsed / 3600
		mins := (elapsed % 3600) / 60
		secs := elapsed % 60
		b.WriteString(m.ui.success.Render(fmt.Sprintf("%s Finished in %dh %dm %ds", m.cfg.Glyphs["ok"], hours, mins, secs)))
		b.WriteString("\n\n")
	}

	if hasErrors {
		lines := []string{m.ui.error.Render("Attention needed")}
		if c.shellFailed {
			lines = append(lines, m.ui.normal.Render("- Shell build failed (check missing dependencies in log)."))
		}
		if len(c.failedPkgs) > 0 {
			lines = append(lines, m.ui.normal.Render("- Failed packages: "+strings.Join(c.failedPkgs, ", ")))
		}
		b.WriteString(m.ui.errorBox.Render(strings.Join(lines, "\n")))
		b.WriteString("\n\n")
	}

	b.WriteString(m.ui.sectionLabel("Quick start & shortcuts"))
	b.WriteString("\n\n")
	for _, s := range []string{
		"Super / Super+Space   Application Launcher",
		"Super+Return          Terminal",
		"Super+/               Show Keybinds Helper",
		"Super+V               Clipboard History",
		"Super+Shift+S         Screenshot Tool",
		"Super+B               Sidebar & Notifications",
	} {
		b.WriteString(m.ui.normal.Render("  " + s))
		b.WriteByte('\n')
	}
	b.WriteByte('\n')
	b.WriteString(m.ui.sectionLabel("Next steps"))
	b.WriteString("\n\n")
	b.WriteString(m.ui.normal.Render("- Log out and back in to start your new Caelestia session."))
	b.WriteByte('\n')
	b.WriteString(m.ui.subtle.Render("- Full log saved to: " + c.logPath))
	b.WriteString("\n\n")

	m.renderFooter(&b, "L", " to view the full log, ", "Y/n", " to log out now")
	return b.String()
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

	var b strings.Builder
	b.WriteString(m.ui.title.Render("Install Log"))
	b.WriteString("\n\n")
	for i := 0; i < show && lv.viewTop+i < len(lv.lines); i++ {
		l := lv.lines[lv.viewTop+i]
		text := fit(l, m.width-2)
		switch {
		case strings.Contains(l, "[ERR]"):
			b.WriteString(m.ui.error.Render(text))
		case strings.Contains(l, "[WARN]"):
			b.WriteString(m.ui.warning.Render(text))
		default:
			b.WriteString(m.ui.normal.Render(text))
		}
		b.WriteByte('\n')
	}

	status := "Following"
	if !lv.follow {
		status = "Paused"
	}
	b.WriteString(m.ui.statusBar.Render(status))
	b.WriteString("\n\n")
	b.WriteString(m.ui.subtle.Render("↑/↓/PgUp/PgDn scroll, n/p next issue, ") + m.ui.key.Render("L") + m.ui.subtle.Render(" to go back"))
	return b.String()
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
