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
	b.WriteString(m.renderBanner())
	b.WriteByte('\n')
	b.WriteString(m.ui.subtleItalic.Render("Quickstart for a Caelestia desktop"))
	b.WriteString("\n\n")

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

	enter := m.ui.key.Render("Enter")
	esc := m.ui.key.Render("Esc")
	b.WriteString(m.ui.subtle.Render("Press ") + enter + m.ui.subtle.Render(" to continue, ") + esc + m.ui.subtle.Render(" to quit"))
	return b.String()
}

func (m model) viewAction() string {
	options := make([]listOption, len(m.actions))
	for i, a := range m.actions {
		options[i] = listOption{label: a.title, desc: a.help}
	}
	var b strings.Builder
	b.WriteString(m.ui.title.Render("Caelestia Setup"))
	b.WriteString("\n\n")
	m.renderOptionList(&b, options, m.actionCursor)
	b.WriteByte('\n')
	b.WriteString(m.ui.subtle.Render("Use ") + m.ui.key.Render("↑/↓") + m.ui.subtle.Render(" to navigate, ") +
		m.ui.key.Render("Enter") + m.ui.subtle.Render(" to select, ") + m.ui.key.Render("Esc") + m.ui.subtle.Render(" to quit"))
	return b.String()
}

func (m model) viewOptional() string {
	options := []listOption{
		{"Yes - also theme my applications", "Adds theming for VSCode/VSCodium, Zed, Spicetify, Discord/Equibop, Todoist, and Firefox."},
		{"No - keep the standard install", "Installs the shell, packages, and theming only."},
	}
	var b strings.Builder
	b.WriteString(m.ui.title.Render("Optional App Theming"))
	b.WriteString("\n\n")
	b.WriteString(m.ui.normal.Render("Caelestia can also theme your applications."))
	b.WriteString("\n\n")
	m.renderOptionList(&b, options, m.optionalCursor)
	b.WriteByte('\n')
	b.WriteString(m.ui.subtle.Render("Use ") + m.ui.key.Render("↑/↓") + m.ui.subtle.Render(" to choose, ") +
		m.ui.key.Render("Enter") + m.ui.subtle.Render(" to confirm, ") + m.ui.key.Render("Esc") + m.ui.subtle.Render(" to cancel installation"))
	return b.String()
}

func (m model) viewSudo() string {
	var b strings.Builder
	b.WriteString(m.ui.title.Render("Privilege Escalation"))
	b.WriteString("\n\n")
	b.WriteString(m.ui.normal.Render("Root privileges are required to install packages."))
	b.WriteString("\n\n")
	b.WriteString(m.ui.highlight.Render("Password: ") + m.password.View())
	if m.sudoError != "" {
		b.WriteString("\n\n")
		b.WriteString(m.ui.errorBox.Render(m.sudoError))
	}
	b.WriteString("\n\n")
	b.WriteString(m.ui.subtle.Render("Press ") + m.ui.key.Render("Enter") + m.ui.subtle.Render(" to verify, ") + m.ui.key.Render("Esc") + m.ui.subtle.Render(" to cancel"))
	return b.String()
}

func (m model) viewConfigure() string {
	if len(m.menuStack) == 0 {
		return ""
	}
	frame := m.menuStack[len(m.menuStack)-1]
	var b strings.Builder
	b.WriteString(m.ui.title.Render(frame.title))
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
	b.WriteString(m.ui.subtle.Render("Use ") + m.ui.key.Render("↑/↓") + m.ui.subtle.Render(" to navigate, ") +
		m.ui.key.Render("Enter") + m.ui.subtle.Render(" to toggle/select, ") + m.ui.key.Render("←/Esc") + m.ui.subtle.Render(" to go back"))
	return b.String()
}

func (m model) viewReview() string {
	var b strings.Builder
	b.WriteString(m.ui.title.Render("Review Installation"))
	b.WriteString("\n\n")

	var all []string
	for _, ph := range m.cfg.Manifest.Phases {
		all = append(all, m.ui.highlight.Render(ph.Name))
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

	maxRows := m.height - 8
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
	b.WriteString(m.ui.subtle.Render("Press ") + m.ui.key.Render("Enter") + m.ui.subtle.Render(" to begin installation, ") + m.ui.key.Render("Esc") + m.ui.subtle.Render(" to go back"))
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
	b.WriteString(m.ui.title.Render("Installing"))
	b.WriteString("\n\n")
	b.WriteString(m.ui.statusBar.Width(m.width - 2).Render(m.progressBar()))
	b.WriteString("\n\n")

	var all []string
	focus := 0
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
				rowText := "  " + spinnerFrames[ins.spinner%len(spinnerFrames)] + " " + steps[i].Name
				all = append(all, m.ui.selectedRow(rowText, m.width-2))
			} else {
				all = append(all, m.ui.statusText(status, text))
			}
		}
	}

	maxRows := m.height - 8
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
	for _, l := range visible(all, top, maxRows) {
		b.WriteString(l)
		b.WriteByte('\n')
	}
	b.WriteByte('\n')
	b.WriteString(m.ui.subtle.Render("Press ") + m.ui.key.Render("L") + m.ui.subtle.Render(" for the full log, ") + m.ui.key.Render("Ctrl+C") + m.ui.subtle.Render(" to cancel"))
	return b.String()
}

func (m model) progressBar() string {
	total := len(m.cfg.Manifest.Steps)
	current := m.install.current
	if current > total {
		current = total
	}
	barW := m.width - 14
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
	var b strings.Builder
	b.WriteString(m.ui.title.Render("Installation Error"))
	b.WriteString("\n\n")

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
	b.WriteString(m.ui.title.Render(title))
	b.WriteString("\n\n")

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

	b.WriteString(m.ui.subtle.Render("Press ") + m.ui.key.Render("L") + m.ui.subtle.Render(" to view the full log, ") + m.ui.key.Render("Y/n") + m.ui.subtle.Render(" to log out now"))
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
