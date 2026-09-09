// Package sudo collects and verifies the sudo password before configuring or
// installing.
package sudo

import (
	"fmt"
	"strings"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/runner"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/optional"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/progress"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

type Model struct {
	ctx      *app.Context
	password textinput.Model
	errMsg   string
	attempts int
}

func New(ctx *app.Context) Model {
	ti := textinput.New()
	ti.Placeholder = "sudo password"
	ti.EchoMode = textinput.EchoPassword
	ti.CharLimit = 256
	ti.Focus()
	return Model{ctx: ctx, password: ti}
}

func (m Model) Init() tea.Cmd { return textinput.Blink }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := msg.(tea.KeyPressMsg)
	if !ok {
		return m, nil
	}
	switch key.String() {
	case "esc":
		m.ctx.ExitCode = 0
		return m, tea.Quit
	case "enter":
		if m.password.Value() == "" {
			return m, nil
		}
		return m.submit()
	default:
		var cmd tea.Cmd
		m.password, cmd = m.password.Update(key)
		return m, cmd
	}
}

func (m Model) submit() (tea.Model, tea.Cmd) {
	pw := m.password.Value()
	m.errMsg = "Verifying..."

	if runner.VerifySudoPassword(pw) {
		dir, err := runner.SetupSudoEnvironment(pw)
		if err != nil {
			m.errMsg = "Could not prepare secure sudo helpers."
			m.password.SetValue("")
			return m, nil
		}
		m.ctx.SudoBinDir = dir
		return m.enterConfigure()
	}

	m.attempts++
	if m.attempts >= 3 {
		m.ctx.ExitCode = 1
		return m, tea.Quit
	}
	m.errMsg = fmt.Sprintf("Incorrect password, please try again. (%d/3)", m.attempts)
	m.password.SetValue("")
	return m, nil
}

// enterConfigure mirrors the old model's enterConfigure: bundles with no menu
// at all skip straight to installing.
func (m Model) enterConfigure() (tea.Model, tea.Cmd) {
	if len(m.ctx.Cfg.Menu.Menu) == 0 {
		p := progress.New(m.ctx)
		return m, app.Push(p)
	}
	return m, app.Push(optional.New(m.ctx))
}

func (m Model) View() tea.View {
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Authentication")
	b.WriteString(m.ctx.Theme.Normal.Render("Root privileges are required to install packages."))
	b.WriteString("\n\n")
	b.WriteString(m.ctx.Theme.Subtle.Render("sudo"))
	b.WriteString("\n")
	b.WriteString(m.ctx.Theme.Highlight.Render("Password: ") + m.password.View())
	if m.errMsg != "" {
		b.WriteString("\n\n")
		b.WriteString(m.ctx.Theme.ErrorBox.Render(m.errMsg))
	}
	b.WriteString("\n\n")
	widgets.RenderFooter(&b, m.ctx.Theme, "Enter", " to verify, ", "Esc", " to cancel")
	return tea.NewView(b.String())
}
