// Package welcome is the installer's first screen: a short pitch for what
// gets installed, before moving on to the action picker.
package welcome

import (
	"fmt"
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/action"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/util"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

type Model struct {
	ctx *app.Context
}

func New(ctx *app.Context) Model { return Model{ctx: ctx} }

func (m Model) Init() tea.Cmd { return nil }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := msg.(tea.KeyPressMsg)
	if !ok {
		return m, nil
	}
	switch key.String() {
	case "enter", "space":
		return m, app.Push(action.New(m.ctx))
	case "esc":
		m.ctx.ActionResult = "exit"
		m.ctx.ExitCode = 0
		return m, tea.Quit
	}
	return m, nil
}

func (m Model) View() tea.View {
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Caelestia Installer")

	b.WriteString(m.ctx.Theme.Normal.Render("System: " + util.DistroLabel(m.ctx.BaseDistro)))
	b.WriteString("\n\n")

	b.WriteString(m.ctx.Theme.SectionLabel("What you get"))
	b.WriteString("\n\n")

	features := []struct{ tag, desc string }{
		{"[shell]", "Caelestia KDE shell (Quickshell)"},
		{"[packages]", "fish, foot, btop, fastfetch, and more"},
		{"[theme]", "Material You dynamic colors and Darkly"},
		{"[config]", "keybindings, window rules, and autostart"},
	}
	tagStyle := m.ctx.Theme.Accent.Bold(true)
	for _, feat := range features {
		fmt.Fprintf(&b, "  %s %s\n", tagStyle.Render(fmt.Sprintf("%-12s", feat.tag)), m.ctx.Theme.Normal.Render(feat.desc))
	}
	b.WriteByte('\n')

	widgets.RenderFooter(&b, m.ctx.Theme, "Enter", " to continue, ", "Esc", " to quit")
	return tea.NewView(b.String())
}
