package main

import (
	"fmt"
	"os/exec"
	"time"

	"charm.land/bubbles/v2/progress"
	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"
)

type screen int

const (
	screenWelcome screen = iota
	screenAction
	screenOptional
	screenSudo
	screenConfigure
	screenReview
	screenInstall
	screenLog
	screenComplete
)

type tickMsg struct{}

type stepFinishedMsg struct {
	exitCode    int
	startFailed bool
}

type interruptMsg struct{}

type actionItem struct {
	id    string
	title string
	help  string
}

type menuFrame struct {
	title  string
	items  []MenuItem
	cursor int
}

type installState struct {
	statuses        []string
	current         int
	spinner         int
	running         bool
	stepStartOffset int64
	logPath         string
	cmd             *exec.Cmd
	dialog          bool
	detail          []string
	errCursor       int
	finished        bool
	startTime       time.Time
	stepStart       time.Time
	liveLines       []string
	progress        progress.Model
}

type completeState struct {
	logPath     string
	startEpoch  int64
	failedPkgs  []string
	shellFailed bool
}

type logState struct {
	logPath string
	lines   []string
	issues  []int
	viewTop int
	follow  bool
}

type model struct {
	screen     screen
	prevScreen screen
	width      int
	height     int

	cfg     *config
	ui      ui
	answers map[string]string

	bundleDir  string
	baseDistro string
	sudoBinDir string
	logout     bool
	exitCode   int

	actions      []actionItem
	actionCursor int
	actionResult string

	optionalCursor int

	password     textinput.Model
	sudoError    string
	sudoAttempts int

	menuStack []menuFrame

	reviewScroll int

	install  *installState
	logView  *logState
	complete *completeState
}

func initialModel(cfg *config, bundleDir, baseDistro string) model {
	ti := textinput.New()
	ti.Placeholder = "sudo password"
	ti.EchoMode = textinput.EchoPassword
	ti.CharLimit = 256
	ti.Focus()

	actions := []actionItem{
		{id: "install", title: "Install Caelestia", help: "Install the shell, packages, themes, and configs."},
	}
	if isCaelestiaInstalled() {
		actions = append(actions,
			actionItem{id: "update", title: "Update Caelestia", help: "Pull the latest code and rebuild the shell."},
			actionItem{id: "uninstall", title: "Uninstall Caelestia", help: "Remove the shell and restore backups where available."},
		)
	}
	actions = append(actions, actionItem{id: "exit", title: "Exit", help: "Leave without changing anything."})

	return model{
		screen:     screenWelcome,
		cfg:        cfg,
		ui:         newUI(cfg),
		answers:    map[string]string{},
		bundleDir:  bundleDir,
		baseDistro: baseDistro,
		password:   ti,
		actions:    actions,
	}
}

func (m model) Init() tea.Cmd {
	return textinput.Blink
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		if m.install != nil {
			m.install.progress.SetWidth(progressBarWidth(msg.Width))
		}
		return m, nil

	case interruptMsg:
		return m.handleInterrupt()

	case stepFinishedMsg:
		return m.handleStepFinished(msg)

	case tickMsg:
		if m.screen == screenInstall && m.install != nil && m.install.running {
			m.install.spinner++
			m.refreshLive()
		}
		if m.screen == screenLog {
			m.refreshLog()
		}
		return m, m.tickCmd()

	case tea.KeyPressMsg:
		return m.handleKey(msg)

	case progress.FrameMsg:
		if m.screen == screenInstall && m.install != nil {
			updated, cmd := m.install.progress.Update(msg)
			m.install.progress = updated
			return m, cmd
		}
	}
	return m, nil
}

func (m model) tickCmd() tea.Cmd {
	if m.screen != screenInstall && m.screen != screenLog {
		return nil
	}
	return tea.Tick(200*time.Millisecond, func(time.Time) tea.Msg { return tickMsg{} })
}

func (m model) handleInterrupt() (tea.Model, tea.Cmd) {
	if m.install != nil && m.install.cmd != nil {
		signalTerminate(m.install.cmd.Process)
		m.install.cmd = nil
	}
	m.exitCode = 130
	return m, tea.Quit
}

func (m model) handleKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	key := msg.String()

	if key == "ctrl+c" {
		return m.handleInterrupt()
	}

	switch m.screen {
	case screenWelcome:
		switch key {
		case "enter", "space":
			m.screen = screenAction
			return m, nil
		case "esc":
			m.actionResult = "exit"
			m.exitCode = 0
			return m, tea.Quit
		}
		return m, nil

	case screenAction:
		return m.handleActionKey(key)

	case screenOptional:
		return m.handleOptionalKey(key)

	case screenSudo:
		return m.handleSudoKey(msg, key)

	case screenConfigure:
		return m.handleConfigureKey(key)

	case screenReview:
		return m.handleReviewKey(key)

	case screenInstall:
		return m.handleInstallKey(key)

	case screenLog:
		return m.handleLogKey(key)

	case screenComplete:
		return m.handleCompleteKey(key)
	}
	return m, nil
}

func (m model) handleActionKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "up":
		if m.actionCursor > 0 {
			m.actionCursor--
		}
	case "down":
		if m.actionCursor < len(m.actions)-1 {
			m.actionCursor++
		}
	case "enter", "space":
		sel := m.actions[m.actionCursor].id
		switch sel {
		case "update", "uninstall", "exit":
			m.actionResult = sel
			m.exitCode = 0
			return m, tea.Quit
		default:
			m.screen = screenSudo
			m.sudoAttempts = 0
			m.sudoError = ""
			m.password.SetValue("")
			return m, textinput.Blink
		}
	case "esc":
		m.actionResult = "exit"
		m.exitCode = 0
		return m, tea.Quit
	}
	return m, nil
}

func (m model) handleOptionalKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "up":
		if m.optionalCursor > 0 {
			m.optionalCursor--
		}
	case "down":
		if m.optionalCursor < 1 {
			m.optionalCursor++
		}
	case "enter", "space":
		if m.optionalCursor == 0 {
			enableOptionalApps(m.cfg.Menu, m.answers)
		}
		m.screen = screenConfigure
		return m, nil
	case "esc":
		m.exitCode = 0
		return m, tea.Quit
	}
	return m, nil
}

func (m model) handleSudoKey(msg tea.KeyPressMsg, key string) (tea.Model, tea.Cmd) {
	switch key {
	case "esc":
		m.exitCode = 0
		return m, tea.Quit
	case "enter":
		if m.password.Value() == "" {
			return m, nil
		}
		return m.submitPassword()
	default:
		var cmd tea.Cmd
		m.password, cmd = m.password.Update(msg)
		return m, cmd
	}
}

func (m model) submitPassword() (tea.Model, tea.Cmd) {
	pw := m.password.Value()
	m.sudoError = "Verifying..."

	if verifySudoPassword(pw) {
		dir, err := setupSudoEnvironment(pw)
		if err != nil {
			m.sudoError = "Could not prepare secure sudo helpers."
			m.password.SetValue("")
			return m, nil
		}
		m.sudoBinDir = dir
		m.enterConfigure()
		return m, nil
	}

	m.sudoAttempts++
	if m.sudoAttempts >= 3 {
		m.exitCode = 1
		return m, tea.Quit
	}
	m.sudoError = fmt.Sprintf("Incorrect password, please try again. (%d/3)", m.sudoAttempts)
	m.password.SetValue("")
	return m, nil
}

func (m *model) enterConfigure() {
	if len(m.cfg.Menu.Menu) == 0 {
		m.beginInstall()
		return
	}
	seedMenuDefaults(m.cfg.Menu.Menu, m.answers)
	m.menuStack = []menuFrame{{title: "CONFIGURATION", items: m.cfg.Menu.Menu, cursor: 0}}
	m.screen = screenOptional
}

func (m model) handleConfigureKey(key string) (tea.Model, tea.Cmd) {
	if len(m.menuStack) == 0 {
		return m, nil
	}
	frame := &m.menuStack[len(m.menuStack)-1]

	switch key {
	case "up":
		if frame.cursor > 0 {
			frame.cursor--
		}
	case "down":
		if frame.cursor < len(frame.items)-1 {
			frame.cursor++
		}
	case "left":
		item := frame.items[frame.cursor]
		if item.Type == "select" {
			m.cycleSelect(frame, item, -1)
		} else {
			return m.backOutOfMenu()
		}
	case "right":
		item := frame.items[frame.cursor]
		if item.Type == "select" {
			m.cycleSelect(frame, item, 1)
		}
	case "enter", "space":
		return m.activateMenuItem()
	case "esc":
		return m.backOutOfMenu()
	}
	return m, nil
}

func (m model) backOutOfMenu() (tea.Model, tea.Cmd) {
	if len(m.menuStack) == 1 {
		m.exitCode = 0
		return m, tea.Quit
	}
	m.menuStack = m.menuStack[:len(m.menuStack)-1]
	return m, nil
}

func (m model) activateMenuItem() (tea.Model, tea.Cmd) {
	frame := &m.menuStack[len(m.menuStack)-1]
	item := frame.items[frame.cursor]
	switch item.Type {
	case "action":
		if item.ID == "action_back" {
			return m.backOutOfMenu()
		}
		if item.ID == "action_review" || item.ID == "action_proceed" {
			m.screen = screenReview
			m.reviewScroll = 0
			return m, nil
		}
	case "submenu":
		m.menuStack = append(m.menuStack, menuFrame{title: item.Title, items: item.Items, cursor: 0})
	case "boolean":
		if m.answers[item.ID] == "true" {
			m.answers[item.ID] = "false"
		} else {
			m.answers[item.ID] = "true"
		}
	case "select":
		m.cycleSelect(frame, item, 1)
	}
	return m, nil
}

func (m model) cycleSelect(frame *menuFrame, item MenuItem, dir int) {
	idx := -1
	for i, o := range item.Options {
		if o == m.answers[item.ID] {
			idx = i
			break
		}
	}
	n := len(item.Options)
	if n == 0 {
		return
	}
	idx = (idx + dir + n) % n
	m.answers[item.ID] = item.Options[idx]
}

func (m model) handleReviewKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "enter", "space":
		m.beginInstall()
		return m, m.installCmd()
	case "esc", "left":
		m.screen = screenConfigure
		return m, nil
	case "up":
		if m.reviewScroll >= 3 {
			m.reviewScroll -= 3
		} else {
			m.reviewScroll = 0
		}
	case "down":
		m.reviewScroll += 3
	}
	return m, nil
}

func (m *model) beginInstall() {
	exportAnswers(m.answers)
	persistInstallEnv(m.answers)
	_ = m.prepareInstallEnv()
	m.install = &installState{
		statuses:  make([]string, len(m.cfg.Manifest.Steps)),
		logPath:   m.installLogPath(),
		startTime: time.Now(),
		progress:  progress.New(progress.WithColors(m.ui.c("seed"), m.ui.c("secondary")), progress.WithFillCharacters('█', '░')),
	}
	m.install.progress.SetWidth(progressBarWidth(m.width))
	for i := range m.install.statuses {
		m.install.statuses[i] = statusPending
	}
	m.screen = screenInstall
}

func (m model) installCmd() tea.Cmd {
	return tea.Batch(m.tickCmd(), m.startStepCmd(0))
}

func (m model) startStepCmd(i int) tea.Cmd {
	m2, cmd := m.startStep(i)
	m.install = m2.install
	return cmd
}

func (m model) handleStepFinished(msg stepFinishedMsg) (tea.Model, tea.Cmd) {
	ins := m.install
	if ins == nil || ins.finished {
		return m, nil
	}
	i := ins.current
	ins.running = false
	ins.cmd = nil

	if msg.exitCode == 0 {
		if containsWarn(readLogDelta(ins.logPath, ins.stepStartOffset)) {
			ins.statuses[i] = statusWarn
		} else {
			ins.statuses[i] = statusOK
		}
		return m.advanceStep()
	}

	ins.statuses[i] = statusFailed
	if msg.startFailed {
		ins.detail = []string{"Could not start the step script."}
	} else {
		ins.detail = readLogTailLines(ins.logPath, 12)
		if len(ins.detail) > 10 {
			ins.detail = ins.detail[len(ins.detail)-10:]
		}
	}
	ins.errCursor = 0
	ins.dialog = true
	return m, nil
}

func (m model) handleInstallKey(key string) (tea.Model, tea.Cmd) {
	ins := m.install
	if ins == nil {
		return m, nil
	}

	if ins.dialog {
		switch key {
		case "left":
			if ins.errCursor > 0 {
				ins.errCursor--
			}
		case "right":
			if ins.errCursor < 2 {
				ins.errCursor++
			}
		case "enter", "space":
			switch ins.errCursor {
			case 0: // retry
				ins.dialog = false
				return m.startStep(ins.current)
			case 1: // ignore
				ins.statuses[ins.current] = statusIgnored
				ins.dialog = false
				return m.advanceStep()
			case 2: // exit
				m.exitCode = 1
				return m, tea.Quit
			}
		case "esc":
			m.exitCode = 1
			return m, tea.Quit
		}
		return m, nil
	}

	switch key {
	case "l", "L", "shift+tab":
		m.prevScreen = screenInstall
		m.screen = screenLog
		m.logView = &logState{logPath: ins.logPath, follow: true}
		m.refreshLog()
		return m, m.tickCmd()
	}
	return m, nil
}

func (m model) handleLogKey(key string) (tea.Model, tea.Cmd) {
	lv := m.logView
	if lv == nil {
		return m, nil
	}
	switch key {
	case "l", "L", "shift+tab", "esc":
		m.screen = m.prevScreen
		return m, nil
	case "up":
		lv.follow = false
		if lv.viewTop > 0 {
			lv.viewTop--
		}
	case "down":
		if !lv.follow {
			lv.viewTop++
		}
	case "pgup":
		lv.follow = false
		lv.viewTop -= m.logPage()
		if lv.viewTop < 0 {
			lv.viewTop = 0
		}
	case "pgdown":
		if !lv.follow {
			lv.viewTop += m.logPage()
		}
	case "home":
		lv.follow = false
		lv.viewTop = 0
	case "end":
		lv.follow = true
	case "n", "N":
		for _, idx := range lv.issues {
			if idx > lv.viewTop {
				lv.follow = false
				lv.viewTop = idx - m.logPage()/2
				if lv.viewTop < 0 {
					lv.viewTop = 0
				}
				break
			}
		}
	case "p", "P":
		for i := len(lv.issues) - 1; i >= 0; i-- {
			if lv.issues[i] < lv.viewTop {
				lv.follow = false
				lv.viewTop = lv.issues[i] - m.logPage()/2
				if lv.viewTop < 0 {
					lv.viewTop = 0
				}
				break
			}
		}
	}
	return m, nil
}

func (m model) logPage() int {
	page := m.height - 7
	if page < 1 {
		return 1
	}
	return page
}

func (m model) handleCompleteKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "y", "Y", "enter":
		m.logout = true
		return m, tea.Quit
	case "n", "N", "esc":
		m.logout = false
		return m, tea.Quit
	case "l", "L":
		m.prevScreen = screenComplete
		m.screen = screenLog
		m.logView = &logState{logPath: m.complete.logPath, follow: true}
		m.refreshLog()
		return m, m.tickCmd()
	}
	return m, nil
}
