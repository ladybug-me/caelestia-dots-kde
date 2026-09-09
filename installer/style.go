package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// ui holds resolved styles built from the theme palette for a minimal,
// sleek terminal UI: a quiet wordmark, highlighted selections, and restrained
// accent usage.
type ui struct {
	cfg *config

	banner       lipgloss.Style
	title        lipgloss.Style
	normal       lipgloss.Style
	bold         lipgloss.Style
	subtle       lipgloss.Style
	subtleItalic lipgloss.Style
	accent       lipgloss.Style
	accentItalic lipgloss.Style
	highlight    lipgloss.Style
	selected     lipgloss.Style
	key          lipgloss.Style
	success      lipgloss.Style
	warning      lipgloss.Style
	error        lipgloss.Style
	titleBox     lipgloss.Style
	infoBox      lipgloss.Style
	errorBox     lipgloss.Style
	statusBar    lipgloss.Style
	button       lipgloss.Style
	codeBlock    lipgloss.Style
}

func paletteColor(cfg *config, name string) lipgloss.Color {
	if v, ok := cfg.Palette[name]; ok && strings.HasPrefix(v, "#") && len(v) == 7 {
		return lipgloss.Color(v)
	}
	switch name {
	case "primary":
		return lipgloss.Color("#88c0d0")
	case "accent":
		return lipgloss.Color("#81a1c1")
	case "seed":
		return lipgloss.Color("#5e81ac")
	case "container":
		return lipgloss.Color("#3b4252")
	case "surface":
		return lipgloss.Color("#2e3440")
	case "on_surface":
		return lipgloss.Color("#eceff4")
	case "secondary":
		return lipgloss.Color("#8fbcbb")
	case "tertiary":
		return lipgloss.Color("#b48ead")
	case "muted":
		return lipgloss.Color("#6c7a89")
	case "success":
		return lipgloss.Color("#a3be8c")
	case "warning":
		return lipgloss.Color("#ebcb8b")
	case "error":
		return lipgloss.Color("#bf616a")
	}
	return lipgloss.Color("")
}

func newUI(cfg *config) ui {
	c := func(name string) lipgloss.Color { return paletteColor(cfg, name) }
	dark := c("surface")

	return ui{
		cfg:          cfg,
		banner:       lipgloss.NewStyle().Foreground(c("primary")).Bold(true).MarginBottom(1),
		title:        lipgloss.NewStyle().Foreground(c("primary")).Bold(true).MarginLeft(1).MarginBottom(1),
		normal:       lipgloss.NewStyle().Foreground(c("on_surface")),
		bold:         lipgloss.NewStyle().Foreground(c("on_surface")).Bold(true),
		subtle:       lipgloss.NewStyle().Foreground(c("muted")),
		subtleItalic: lipgloss.NewStyle().Foreground(c("muted")).Italic(true),
		accent:       lipgloss.NewStyle().Foreground(c("accent")),
		accentItalic: lipgloss.NewStyle().Foreground(c("accent")).Italic(true),
		highlight:    lipgloss.NewStyle().Foreground(c("primary")).Bold(true),
		selected:     lipgloss.NewStyle().Foreground(c("accent")).Bold(true),
		key:          lipgloss.NewStyle().Foreground(c("accent")).Bold(true),
		success:      lipgloss.NewStyle().Foreground(c("success")).Bold(true),
		warning:      lipgloss.NewStyle().Foreground(c("warning")),
		error:        lipgloss.NewStyle().Foreground(c("error")),
		titleBox:     lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(c("primary")).Padding(0, 2).MarginBottom(1),
		infoBox:      lipgloss.NewStyle().Border(lipgloss.NormalBorder()).BorderForeground(c("muted")).Padding(0, 1).MarginBottom(1),
		errorBox:     lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(c("error")).Padding(1, 2).MarginBottom(1),
		statusBar:    lipgloss.NewStyle().Foreground(dark).Background(c("primary")).Padding(0, 1),
		button:       lipgloss.NewStyle().Foreground(dark).Background(c("primary")).Padding(0, 2).Bold(true),
		codeBlock:    lipgloss.NewStyle().Background(c("container")).Foreground(c("on_surface")).Padding(1, 2).MarginLeft(2),
	}
}

func (u ui) c(name string) lipgloss.Color { return paletteColor(u.cfg, name) }

// row renders one selectable line at the given width.
func (u ui) row(s string, width int) string {
	return lipgloss.NewStyle().Foreground(u.c("on_surface")).Padding(0, 1).Width(width).Render(s)
}

// selectedRow renders the focused line as a soft full-width highlight.
func (u ui) selectedRow(s string, width int) string {
	return lipgloss.NewStyle().
		Background(u.c("container")).
		Foreground(u.c("accent")).
		Bold(true).
		Padding(0, 1).
		Width(width).
		Render(s)
}

// sectionLabel renders a quiet, uppercase section heading.
func (u ui) sectionLabel(s string) string {
	return lipgloss.NewStyle().Foreground(u.c("muted")).Render(strings.ToUpper(s))
}

func (u ui) statusText(status, s string) string {
	return lipgloss.NewStyle().Foreground(u.c(statusColorName(status))).Render(s)
}
