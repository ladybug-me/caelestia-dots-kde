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
	cfg    *config.Config
	isDark bool

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

// defaultDark and defaultLight are the installer's own identity - not tied to
// the shell's Material You palette - used whenever theme.json omits a name.
var defaultDark = map[string]string{
	"primary":    "#7dd3fc",
	"accent":     "#a78bfa",
	"seed":       "#6366f1",
	"container":  "#1e293b",
	"surface":    "#0f172a",
	"on_surface": "#e2e8f0",
	"secondary":  "#34d399",
	"tertiary":   "#f472b6",
	"muted":      "#64748b",
	"success":    "#4ade80",
	"warning":    "#fbbf24",
	"error":      "#f87171",
}

var defaultLight = map[string]string{
	"primary":    "#0369a1",
	"accent":     "#6d28d9",
	"seed":       "#4338ca",
	"container":  "#e2e8f0",
	"surface":    "#f8fafc",
	"on_surface": "#0f172a",
	"secondary":  "#047857",
	"tertiary":   "#be185d",
	"muted":      "#64748b",
	"success":    "#15803d",
	"warning":    "#b45309",
	"error":      "#b91c1c",
}

// PaletteColor resolves a named palette entry to a color for the given
// background mode, falling back to the installer's built-in palette when
// theme.json doesn't define it.
func PaletteColor(cfg *config.Config, isDark bool, name string) color.Color {
	themed := cfg.Theme.Palette.Dark
	fallback := defaultDark
	if !isDark {
		themed = cfg.Theme.Palette.Light
		fallback = defaultLight
	}
	if v, ok := themed[name]; ok && strings.HasPrefix(v, "#") && len(v) == 7 {
		return lipgloss.Color(v)
	}
	if v, ok := fallback[name]; ok {
		return lipgloss.Color(v)
	}
	return lipgloss.Color("")
}

// New builds a UI style set from the loaded config for the given background
// mode. Call again (e.g. from the router) once the terminal's actual
// background color is known, to switch from the default dark assumption.
func New(cfg *config.Config, isDark bool) UI {
	c := func(name string) color.Color { return PaletteColor(cfg, isDark, name) }
	dark := c("surface")

	return UI{
		cfg:          cfg,
		isDark:       isDark,
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

// Color resolves a named palette entry using this UI's config and mode.
func (u UI) Color(name string) color.Color { return PaletteColor(u.cfg, u.isDark, name) }

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
