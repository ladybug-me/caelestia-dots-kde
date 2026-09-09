// Package app provides the installer's navigation router: a stack of
// independent tea.Model screens plus the shared Context they read and mutate.
package app

import (
	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/theme"
)

// Context is the mutable state shared by every screen. Screens receive a
// pointer to it so their side effects (answers, exit code, hand-off action,
// ...) are still visible to main() after the Program returns, without the
// router having to know about screen-specific fields.
type Context struct {
	Cfg        *config.Config
	Theme      theme.UI
	Answers    map[string]string
	BundleDir  string
	BaseDistro string

	SudoBinDir string

	Width, Height int

	// ExitCode is the process exit code once the program quits.
	ExitCode int
	// ActionResult is set by the Action screen: "", "update", "uninstall",
	// or "exit". Update/uninstall are handed off to their bash scripts by
	// main() after the Program returns.
	ActionResult string
	// Logout is set by the Complete screen when the user asks to log out.
	Logout bool
}

// Interruptible is implemented by screens that own a running subprocess
// (currently only the progress screen) so Ctrl+C can ask it to stop before
// the program quits.
type Interruptible interface {
	Interrupt()
}

// PushMsg asks the router to push a new screen onto the navigation stack.
type PushMsg struct{ Screen tea.Model }

// PopMsg asks the router to pop the current screen off the stack.
type PopMsg struct{}

// InterruptMsg asks the router to stop any running step and quit. Sent by
// main() when the process receives SIGINT/SIGTERM.
type InterruptMsg struct{}

// Push returns a Cmd that navigates to screen.
func Push(screen tea.Model) tea.Cmd {
	return func() tea.Msg { return PushMsg{Screen: screen} }
}

// Pop returns a Cmd that navigates back to the previous screen.
func Pop() tea.Cmd {
	return func() tea.Msg { return PopMsg{} }
}

// Router is the root tea.Model: it owns the navigation stack and forwards
// messages to whichever screen is on top.
type Router struct {
	ctx   *Context
	stack []tea.Model
}

// NewRouter starts the router with first as the only screen on the stack.
func NewRouter(ctx *Context, first tea.Model) *Router {
	return &Router{ctx: ctx, stack: []tea.Model{first}}
}

func (r *Router) top() tea.Model { return r.stack[len(r.stack)-1] }

func (r *Router) Init() tea.Cmd {
	return r.top().Init()
}

func (r *Router) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		r.ctx.Width, r.ctx.Height = msg.Width, msg.Height
		return r, nil

	case tea.KeyPressMsg:
		if msg.String() == "ctrl+c" {
			return r.interrupt()
		}

	case InterruptMsg:
		return r.interrupt()

	case PushMsg:
		r.stack = append(r.stack, msg.Screen)
		return r, msg.Screen.Init()

	case PopMsg:
		if len(r.stack) > 1 {
			r.stack = r.stack[:len(r.stack)-1]
		}
		// Screens must treat Init as safe to call again: popping back to a
		// screen re-runs it so periodic work (spinners, log tailing) that
		// paused while another screen was on top can resume.
		return r, r.top().Init()
	}

	updated, cmd := r.top().Update(msg)
	r.stack[len(r.stack)-1] = updated
	return r, cmd
}

func (r *Router) interrupt() (tea.Model, tea.Cmd) {
	if top, ok := r.top().(Interruptible); ok {
		top.Interrupt()
	}
	r.ctx.ExitCode = 130
	return r, tea.Quit
}

func (r *Router) View() tea.View {
	v := r.top().View()
	v.AltScreen = true
	return v
}
