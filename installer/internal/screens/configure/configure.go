// Package configure renders the drill-down configuration menu (menu.json)
// and hands off to the review screen once the user proceeds.
package configure

import (
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/manifest"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/review"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

// frame is one level of the menu drill-down stack.
type frame struct {
	title  string
	items  []config.MenuItem
	cursor int
}

type Model struct {
	ctx   *app.Context
	stack []frame
}

// New builds the root configuration frame, seeding any unanswered items with
// their menu.json defaults.
func New(ctx *app.Context) Model {
	manifest.SeedMenuDefaults(ctx.Cfg.Menu.Menu, ctx.Answers)
	return Model{
		ctx:   ctx,
		stack: []frame{{title: "CONFIGURATION", items: ctx.Cfg.Menu.Menu, cursor: 0}},
	}
}

func (m Model) Init() tea.Cmd { return nil }

func (m *Model) top() *frame { return &m.stack[len(m.stack)-1] }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := msg.(tea.KeyPressMsg)
	if !ok {
		return m, nil
	}
	f := m.top()
	switch key.String() {
	case "up":
		if f.cursor > 0 {
			f.cursor--
		}
	case "down":
		if f.cursor < len(f.items)-1 {
			f.cursor++
		}
	case "left":
		item := &f.items[f.cursor]
		if item.Type == "select" {
			m.cycleSelect(item, -1)
		} else {
			return m.backOutOfMenu()
		}
	case "right":
		item := &f.items[f.cursor]
		if item.Type == "select" {
			m.cycleSelect(item, 1)
		}
	case "enter", "space":
		return m.activateMenuItem()
	case "esc":
		return m.backOutOfMenu()
	}
	return m, nil
}

func (m Model) backOutOfMenu() (tea.Model, tea.Cmd) {
	if len(m.stack) == 1 {
		m.ctx.ExitCode = 0
		return m, tea.Quit
	}
	m.stack = m.stack[:len(m.stack)-1]
	return m, nil
}

func (m Model) activateMenuItem() (tea.Model, tea.Cmd) {
	f := m.top()
	if len(f.items) == 0 {
		return m, nil
	}
	item := &f.items[f.cursor]
	switch item.Type {
	case "action":
		switch item.ID {
		case "action_back":
			return m.backOutOfMenu()
		case "action_review", "action_proceed":
			return m, app.Push(review.New(m.ctx))
		}
	case "submenu":
		m.stack = append(m.stack, frame{title: item.Title, items: item.Items, cursor: 0})
	case "boolean":
		if m.ctx.Answers[item.ID] == "true" {
			m.ctx.Answers[item.ID] = "false"
		} else {
			m.ctx.Answers[item.ID] = "true"
		}
	case "select":
		m.cycleSelect(item, 1)
	}
	return m, nil
}

func (m Model) cycleSelect(item *config.MenuItem, dir int) {
	if len(item.Options) == 0 {
		return
	}
	cur := m.ctx.Answers[item.ID]
	idx := 0
	for i, opt := range item.Options {
		if opt == cur {
			idx = i
			break
		}
	}
	idx = (idx + dir + len(item.Options)) % len(item.Options)
	m.ctx.Answers[item.ID] = item.Options[idx]
}

func (m Model) View() tea.View {
	f := m.stack[len(m.stack)-1]
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, f.title)
	b.WriteString(m.ctx.Theme.Normal.Render("Choose the components to install and configure."))
	b.WriteString("\n\n")

	options := make([]widgets.ListOption, len(f.items))
	for i, item := range f.items {
		options[i] = widgets.ListOption{
			Label: menuDisplay(item, m.ctx.Answers),
			Desc:  item.Help,
		}
	}
	widgets.RenderOptionList(&b, m.ctx.Theme, m.ctx.Width-2, options, f.cursor)
	b.WriteByte('\n')
	widgets.RenderFooter(&b, m.ctx.Theme, "↑/↓", " to navigate, ", "Enter", " to toggle/select, ", "←/Esc", " to go back")
	return tea.NewView(b.String())
}

func menuDisplay(item config.MenuItem, answers map[string]string) string {
	switch item.Type {
	case "submenu":
		return item.Title + " >"
	case "boolean":
		checkbox := "[ ]"
		if answers[item.ID] == "true" {
			checkbox = "[x]"
		}
		return checkbox + " " + item.Title
	case "select":
		return item.Title + ": < " + answers[item.ID] + " >"
	default:
		return item.Title
	}
}
