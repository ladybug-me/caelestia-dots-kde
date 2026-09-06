package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// ui holds resolved styling helpers backed by the theme palette.
type ui struct {
	cfg *config
}

func (u ui) c(name string) lipgloss.Color {
	if v, ok := u.cfg.Palette[name]; ok && strings.HasPrefix(v, "#") && len(v) == 7 {
		return lipgloss.Color(v)
	}
	switch name {
	case "primary":
		return lipgloss.Color("213")
	case "accent":
		return lipgloss.Color("204")
	case "container":
		return lipgloss.Color("235")
	case "surface":
		return lipgloss.Color("234")
	case "on_surface":
		return lipgloss.Color("253")
	case "secondary":
		return lipgloss.Color("217")
	case "tertiary":
		return lipgloss.Color("222")
	case "muted":
		return lipgloss.Color("245")
	case "success":
		return lipgloss.Color("150")
	case "warning":
		return lipgloss.Color("221")
	case "error":
		return lipgloss.Color("203")
	}
	return lipgloss.Color("")
}

func (u ui) title(s string) string {
	return lipgloss.NewStyle().Bold(true).Foreground(u.c("accent")).Align(lipgloss.Center).Render(s)
}

func (u ui) selected(s string) string {
	return lipgloss.NewStyle().Bold(true).Foreground(u.c("primary")).Render(s)
}

func (u ui) normal(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("on_surface")).Render(s)
}

func (u ui) muted(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("muted")).Render(s)
}

func (u ui) secondary(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("secondary")).Render(s)
}

func (u ui) statusText(status, s string) string {
	return lipgloss.NewStyle().Foreground(u.c(statusColorName(status))).Render(s)
}

func (u ui) box(content string) string {
	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(u.c("accent")).
		Padding(0, 1).
		Render(content)
}

// renderScreen composes a centered title, a boxed body, and a muted footer.
func (m model) renderScreen(title, footer string, lines []string) string {
	body := strings.Join(lines, "\n")
	boxed := m.ui.box(body)
	head := m.ui.title(title)
	out := lipgloss.JoinVertical(lipgloss.Center, head, boxed)
	if footer != "" {
		out = lipgloss.JoinVertical(lipgloss.Center, out, m.ui.muted(footer))
	}
	return out
}
