// Package theme builds lipgloss styles from the loaded palette.
package theme

import (
	"image/color"
	"strings"

	"charm.land/lipgloss/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/manifest"
)

// UI holds resolved styles built from the theme palette for a minimal,
// sleek terminal UI: a quiet wordmark, highlighted selections, and restrained
// accent usage.
type UI struct {
	cfg *config.Config

	Banner       lipgloss.Style
	Title        lipgloss.Style
	Normal       lipgloss.Style
	Bold         lipgloss.Style
	Subtle       lipgloss.Style
	SubtleItalic lipgloss.Style
	Accent       lipgloss.Style
	AccentItalic lipgloss.Style
	Highlight    lipgloss.Style
	Selected     lipgloss.Style
	Key          lipgloss.Style
	Success      lipgloss.Style
	Warning      lipgloss.Style
	Error        lipgloss.Style
	TitleBox     lipgloss.Style
	InfoBox      lipgloss.Style
	ErrorBox     lipgloss.Style
	StatusBar    lipgloss.Style
	Button       lipgloss.Style
	CodeBlock    lipgloss.Style
}

// PaletteColor resolves a named palette entry to a color, falling back to a
// small built-in Nord-like palette when theme.json doesn't define it.
func PaletteColor(cfg *config.Config, name string) color.Color {
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

// New builds a UI style set from the loaded config.
func New(cfg *config.Config) UI {
	c := func(name string) color.Color { return PaletteColor(cfg, name) }
	dark := c("surface")

	return UI{
		cfg:          cfg,
		Banner:       lipgloss.NewStyle().Foreground(c("primary")).Bold(true).MarginBottom(1),
		Title:        lipgloss.NewStyle().Foreground(c("primary")).Bold(true).MarginLeft(1).MarginBottom(1),
		Normal:       lipgloss.NewStyle().Foreground(c("on_surface")),
		Bold:         lipgloss.NewStyle().Foreground(c("on_surface")).Bold(true),
		Subtle:       lipgloss.NewStyle().Foreground(c("muted")),
		SubtleItalic: lipgloss.NewStyle().Foreground(c("muted")).Italic(true),
		Accent:       lipgloss.NewStyle().Foreground(c("accent")),
		AccentItalic: lipgloss.NewStyle().Foreground(c("accent")).Italic(true),
		Highlight:    lipgloss.NewStyle().Foreground(c("primary")).Bold(true),
		Selected:     lipgloss.NewStyle().Foreground(c("accent")).Bold(true),
		Key:          lipgloss.NewStyle().Foreground(c("accent")).Bold(true),
		Success:      lipgloss.NewStyle().Foreground(c("success")).Bold(true),
		Warning:      lipgloss.NewStyle().Foreground(c("warning")),
		Error:        lipgloss.NewStyle().Foreground(c("error")),
		TitleBox:     lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(c("primary")).Padding(0, 2).MarginBottom(1),
		InfoBox:      lipgloss.NewStyle().Border(lipgloss.NormalBorder()).BorderForeground(c("muted")).Padding(0, 1).MarginBottom(1),
		ErrorBox:     lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(c("error")).Padding(1, 2).MarginBottom(1),
		StatusBar:    lipgloss.NewStyle().Foreground(dark).Background(c("primary")).Padding(0, 1),
		Button:       lipgloss.NewStyle().Foreground(dark).Background(c("primary")).Padding(0, 2).Bold(true),
		CodeBlock:    lipgloss.NewStyle().Background(c("container")).Foreground(c("on_surface")).Padding(1, 2).MarginLeft(2),
	}
}

// Color resolves a named palette entry using this UI's config.
func (u UI) Color(name string) color.Color { return PaletteColor(u.cfg, name) }

// Row renders one selectable line at the given width.
func (u UI) Row(s string, width int) string {
	return lipgloss.NewStyle().Foreground(u.Color("on_surface")).Padding(0, 1).Width(width).Render(s)
}

// SelectedRow renders the focused line as a soft full-width highlight.
func (u UI) SelectedRow(s string, width int) string {
	return lipgloss.NewStyle().
		Background(u.Color("container")).
		Foreground(u.Color("accent")).
		Bold(true).
		Padding(0, 1).
		Width(width).
		Render(s)
}

// SectionLabel renders a quiet, uppercase section heading.
func (u UI) SectionLabel(s string) string {
	return lipgloss.NewStyle().Foreground(u.Color("muted")).Render(strings.ToUpper(s))
}

// StatusText renders s in the color associated with status.
func (u UI) StatusText(status, s string) string {
	return lipgloss.NewStyle().Foreground(u.Color(manifest.ColorName(status))).Render(s)
}
