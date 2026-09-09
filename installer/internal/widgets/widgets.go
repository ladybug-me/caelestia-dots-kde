// Package widgets holds small render helpers shared across screens: the
// banner/page header, the keybinding footer, and the selectable option list.
package widgets

import (
	"strings"

	"charm.land/lipgloss/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/theme"
)

// ListOption is one row in a RenderOptionList.
type ListOption struct {
	Label string
	Desc  string
}

// RenderBanner renders theme.json's splash art, or a plain wordmark fallback.
func RenderBanner(ui theme.UI, cfg *config.Config) string {
	art := cfg.Theme.Splash.Art
	if len(art) == 0 {
		art = []string{"Caelestia Installer"}
	}
	artColor := cfg.Theme.Splash.ArtColor
	if artColor == "" {
		artColor = "accent"
	}
	style := lipgloss.NewStyle().Foreground(ui.Color(artColor)).Bold(true)
	lines := make([]string, 0, len(art))
	for _, l := range art {
		lines = append(lines, style.Render(l))
	}
	return lipgloss.JoinVertical(lipgloss.Center, lines...)
}

// RenderPageStart writes the banner and page title shared by every screen.
func RenderPageStart(b *strings.Builder, ui theme.UI, cfg *config.Config, title string) {
	b.WriteString(RenderBanner(ui, cfg))
	b.WriteByte('\n')
	b.WriteString(ui.Title.Render(title))
	b.WriteString("\n\n")
}

// RenderFooter writes a "Press <key> <label>, <key> <label>..." hint line.
// parts alternates key, label, key, label, ...
func RenderFooter(b *strings.Builder, ui theme.UI, parts ...string) {
	b.WriteString(ui.Subtle.Render("Press "))
	for i, part := range parts {
		if i%2 == 0 {
			b.WriteString(ui.Key.Render(part))
		} else {
			b.WriteString(ui.Subtle.Render(part))
		}
	}
}

// RenderOptionList renders a selectable, full-width list with optional
// per-row descriptions.
func RenderOptionList(b *strings.Builder, ui theme.UI, width int, options []ListOption, selected int) {
	if width < 20 {
		width = 20
	}
	for i, opt := range options {
		if i == selected {
			b.WriteString(ui.SelectedRow(opt.Label, width))
		} else {
			b.WriteString(ui.Row(opt.Label, width))
		}
		b.WriteByte('\n')
		if opt.Desc != "" {
			b.WriteString(lipgloss.NewStyle().Foreground(ui.Color("muted")).Padding(0, 1).Render(opt.Desc))
			b.WriteByte('\n')
		}
		if i < len(options)-1 {
			b.WriteByte('\n')
		}
	}
}
