// Package action is the top-level Install/Update/Uninstall/Exit picker.
package action

import (
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/branch"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/sudo"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/util"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

type item struct {
	id, title, help string
}

type Model struct {
	ctx    *app.Context
	items  []item
	cursor int
}

func New(ctx *app.Context) Model {
	items := []item{
		{id: "install", title: "Install Caelestia", help: "Install the shell, packages, themes, and configs."},
	}
	if util.IsCaelestiaInstalled() {
		items = append(items,
			item{id: "update", title: "Update Caelestia", help: "Pull the latest code and rebuild the shell."},
			item{id: "uninstall", title: "Uninstall Caelestia", help: "Remove the shell and restore backups where available."},
		)
	}
	items = append(items, item{id: "exit", title: "Exit", help: "Leave without changing anything."})
	return Model{ctx: ctx, items: items}
}

func (m Model) Init() tea.Cmd { return nil }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := msg.(tea.KeyPressMsg)
	if !ok {
		return m, nil
	}
	switch key.String() {
	case "up":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down":
		if m.cursor < len(m.items)-1 {
			m.cursor++
		}
	case "enter", "space":
		sel := m.items[m.cursor].id
		switch sel {
		case "update":
			return m, app.Push(branch.New(m.ctx))
		case "uninstall", "exit":
			m.ctx.ActionResult = sel
			m.ctx.ExitCode = 0
			return m, tea.Quit
		default:
			return m, app.Push(sudo.New(m.ctx))
		}
	case "esc":
		m.ctx.ActionResult = "exit"
		m.ctx.ExitCode = 0
		return m, tea.Quit
	}
	return m, nil
}

func (m Model) View() tea.View {
	options := make([]widgets.ListOption, len(m.items))
	for i, a := range m.items {
		options[i] = widgets.ListOption{Label: a.title, Desc: a.help}
	}
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Setup")
	b.WriteString(m.ctx.Theme.Subtle.Render("System: " + util.DistroLabel(m.ctx.BaseDistro)))
	b.WriteString("\n\n")
	widgets.RenderOptionList(&b, m.ctx.Theme, m.ctx.Width-2, options, m.cursor)
	b.WriteByte('\n')
	widgets.RenderFooter(&b, m.ctx.Theme, "↑/↓", " to navigate, ", "Enter", " to select, ", "Esc", " to quit")
	return tea.NewView(b.String())
}
