// Package logview shows a scrollable, auto-following tail of the shared
// install log. Reachable from the progress and complete screens.
package logview

import (
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/runner"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/util"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

type tickMsg struct{}

type Model struct {
	ctx     *app.Context
	logPath string

	lines  []string
	issues []int
	top    int
	follow bool
}

func New(ctx *app.Context, logPath string) *Model {
	return &Model{ctx: ctx, logPath: logPath, follow: true}
}

func (m *Model) Init() tea.Cmd {
	m.refreshLog()
	return m.tickCmd()
}

func (m *Model) tickCmd() tea.Cmd {
	return tea.Tick(200*time.Millisecond, func(time.Time) tea.Msg { return tickMsg{} })
}

func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tickMsg:
		if m.follow {
			m.refreshLog()
		}
		return m, m.tickCmd()
	case tea.KeyPressMsg:
		return m.handleKey(msg.String())
	}
	return m, nil
}

func (m *Model) handleKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "l", "L", "shift+tab", "esc":
		return m, app.Pop()
	case "up":
		m.follow = false
		m.scroll(-1)
	case "down":
		m.follow = false
		m.scroll(1)
	case "pgup":
		m.follow = false
		m.scroll(-m.page())
	case "pgdown":
		m.follow = false
		m.scroll(m.page())
	case "home":
		m.follow = false
		m.top = 0
	case "end":
		m.follow = true
		m.refreshLog()
	case "n", "N":
		m.follow = false
		m.jumpIssue(1)
	case "p", "P":
		m.follow = false
		m.jumpIssue(-1)
	}
	return m, nil
}

func (m *Model) scroll(delta int) {
	m.top += delta
	if m.top < 0 {
		m.top = 0
	}
	max := len(m.lines) - m.page()
	if max < 0 {
		max = 0
	}
	if m.top > max {
		m.top = max
	}
}

func (m *Model) jumpIssue(dir int) {
	if len(m.issues) == 0 {
		return
	}
	if dir > 0 {
		for _, idx := range m.issues {
			if idx > m.top {
				m.top = idx
				return
			}
		}
		return
	}
	for i := len(m.issues) - 1; i >= 0; i-- {
		if m.issues[i] < m.top {
			m.top = m.issues[i]
			return
		}
	}
}

func (m *Model) page() int {
	p := m.ctx.Height - 6
	if p < 1 {
		p = 1
	}
	return p
}

func (m *Model) refreshLog() {
	content := runner.ReadLogTailBytes(m.logPath, 1024*1024)
	m.lines = nil
	m.issues = nil
	for _, l := range strings.Split(content, "\n") {
		l = util.StripANSI(l)
		if runner.HasIssue(l) {
			m.issues = append(m.issues, len(m.lines))
		}
		m.lines = append(m.lines, l)
	}
	if m.follow {
		max := len(m.lines) - m.page()
		if max < 0 {
			max = 0
		}
		m.top = max
	}
}

func (m *Model) renderLine(l string) string {
	switch {
	case strings.Contains(l, "[ERR]"):
		return m.ctx.Theme.Error.Render(l)
	case strings.Contains(l, "[WARN]"):
		return m.ctx.Theme.Warning.Render(l)
	default:
		return m.ctx.Theme.Subtle.Render(l)
	}
}

func (m *Model) View() tea.View {
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Install Log")

	show := m.page()
	top := m.top
	end := top + show
	if end > len(m.lines) {
		end = len(m.lines)
	}
	if top > end {
		top = end
	}
	for _, l := range m.lines[top:end] {
		b.WriteString(m.renderLine(l))
		b.WriteByte('\n')
	}
	b.WriteByte('\n')

	status := "Paused"
	if m.follow {
		status = "Following"
	}
	b.WriteString(m.ctx.Theme.Subtle.Render(status))
	b.WriteString("\n\n")

	widgets.RenderFooter(&b, m.ctx.Theme,
		"↑/↓/PgUp/PgDn", " to scroll, ",
		"N/P", " next/prev issue, ",
		"L/Esc", " to go back")
	return tea.NewView(b.String())
}
