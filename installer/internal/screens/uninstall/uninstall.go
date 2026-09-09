// Package uninstall lets the user opt into removing installed packages and
// pick a backup to restore, then swaps in uninstall-steps.json before
// handing off to the shared Review/Progress/Log/Complete flow.
package uninstall

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/review"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

// backupNameRe matches the "YYYYMMDD_HHMMSS" directories 00-backup-themes.sh
// creates under bundleDir/backups.
var backupNameRe = regexp.MustCompile(`^[0-9]{8}_[0-9]{6}$`)

// row is one line of the picker: either the REMOVE_PACKAGES toggle or a
// selectable backup (id "" means "no backup, just remove Caelestia's files").
type row struct {
	isToggle    bool
	id          string
	label, help string
}

type Model struct {
	ctx        *app.Context
	removePkgs bool
	rows       []row
	cursor     int
}

func New(ctx *app.Context) Model {
	m := Model{ctx: ctx}
	m.rows = append(m.rows, row{
		isToggle: true,
		label:    "Remove installed packages",
		help:     "Also uninstalls fish, foot, btop, fastfetch, and other packages the installer added.",
	})
	m.rows = append(m.rows, row{
		label: "Continue without restoring a backup",
		help:  "Leave current configs in place, just remove Caelestia's files.",
	})
	for _, b := range scanBackups(ctx.BundleDir) {
		m.rows = append(m.rows, row{id: b.id, label: b.label, help: b.help})
	}
	return m
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
		if m.cursor < len(m.rows)-1 {
			m.cursor++
		}
	case "enter", "space":
		if m.rows[m.cursor].isToggle {
			m.removePkgs = !m.removePkgs
			return m, nil
		}
		return m.confirm()
	case "esc":
		m.ctx.ExitCode = 0
		return m, tea.Quit
	}
	return m, nil
}

func (m Model) confirm() (tea.Model, tea.Cmd) {
	removePkgs := "false"
	if m.removePkgs {
		removePkgs = "true"
	}
	m.ctx.Answers["SELECTED_BACKUP"] = m.rows[m.cursor].id
	m.ctx.Answers["REMOVE_PACKAGES"] = removePkgs
	// Reuses the Install flow's post-run cache-wipe flag: a "remove
	// packages" uninstall is a deep clean, so clear the installer cache too.
	m.ctx.Answers["REMOVE_CACHE"] = removePkgs
	if steps, err := config.LoadManifest(m.ctx.BundleDir, "uninstall-steps.json"); err == nil {
		m.ctx.Cfg.Manifest = steps
	}
	return m, app.Push(review.New(m.ctx))
}

func (m Model) View() tea.View {
	options := make([]widgets.ListOption, len(m.rows))
	for i, r := range m.rows {
		label := r.label
		if r.isToggle {
			checkbox := "[ ]"
			if m.removePkgs {
				checkbox = "[x]"
			}
			label = checkbox + " " + label
		}
		options[i] = widgets.ListOption{Label: label, Desc: r.help}
	}
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Uninstall Caelestia")
	b.WriteString(m.ctx.Theme.Normal.Render("Choose whether to remove packages, then pick a backup to restore."))
	b.WriteString("\n\n")
	widgets.RenderOptionList(&b, m.ctx.Theme, m.ctx.Width-2, options, m.cursor)
	b.WriteByte('\n')
	widgets.RenderFooter(&b, m.ctx.Theme, "↑/↓", " to navigate, ", "Enter", " to toggle/select, ", "Esc", " to quit")
	return tea.NewView(b.String())
}

type backupOption struct{ id, label, help string }

// scanBackups lists bundleDir/backups newest-first. Unlike menu.json-driven
// screens this can't be static: the backup list only exists once install has
// run at least once.
func scanBackups(bundleDir string) []backupOption {
	dir := filepath.Join(bundleDir, "backups")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var names []string
	for _, e := range entries {
		if e.IsDir() && backupNameRe.MatchString(e.Name()) {
			names = append(names, e.Name())
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(names)))

	opts := make([]backupOption, 0, len(names))
	for _, name := range names {
		full := filepath.Join(dir, name)
		opts = append(opts, backupOption{id: full, label: formatBackupLabel(name), help: backupTags(full)})
	}
	return opts
}

func formatBackupLabel(name string) string {
	if len(name) != len("20260101_120000") {
		return name
	}
	return fmt.Sprintf("%s-%s-%s %s:%s:%s", name[0:4], name[4:6], name[6:8], name[9:11], name[11:13], name[13:15])
}

func backupTags(dir string) string {
	var tags []string
	if hasKnsv(dir) {
		tags = append(tags, "konsave")
	}
	if b, err := os.ReadFile(filepath.Join(dir, "previous_shell.txt")); err == nil {
		if shell := strings.TrimSpace(string(b)); shell != "" {
			tags = append(tags, "shell: "+filepath.Base(shell))
		}
	}
	if _, err := os.Stat(filepath.Join(dir, ".config", "quickshell", "caelestia", "shell.qml")); err == nil {
		tags = append(tags, "contains Caelestia state, not a clean KDE reset")
	}
	return strings.Join(tags, " | ")
}

func hasKnsv(dir string) bool {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".knsv") {
			return true
		}
	}
	return false
}
