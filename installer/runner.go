package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
)

// Marker scanning contract: a step's own output segment is scanned for the
// literal [WARN] marker to promote OK to WARN; the live log view jumps to
// lines containing [WARN] or [ERR].
func containsWarn(s string) bool { return strings.Contains(s, "[WARN]") }

func hasIssue(s string) bool {
	return strings.Contains(s, "[WARN]") || strings.Contains(s, "[ERR]")
}

func (m model) cacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "caelestia-kde")
}

func (m model) installLogPath() string { return filepath.Join(m.cacheDir(), "install.log") }

func readLogTailBytes(path string, maxBytes int64) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return ""
	}
	size := st.Size()
	off := int64(0)
	if size > maxBytes {
		off = size - maxBytes
	}
	buf := make([]byte, size-off)
	if _, err := f.ReadAt(buf, off); err != nil {
		return ""
	}
	return string(buf)
}

func readLogDelta(path string, startOffset int64) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return ""
	}
	size := st.Size()
	if size <= startOffset {
		return ""
	}
	buf := make([]byte, size-startOffset)
	if _, err := f.ReadAt(buf, startOffset); err != nil {
		return ""
	}
	return string(buf)
}

func readLogTailLines(path string, maxLines int) []string {
	content := readLogTailBytes(path, 512*1024)
	var out []string
	for _, l := range strings.Split(content, "\n") {
		out = append(out, stripANSI(l))
	}
	if len(out) > maxLines {
		out = out[len(out)-maxLines:]
	}
	return out
}

func readLines(path string) []string {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var out []string
	for _, l := range strings.Split(string(b), "\n") {
		if strings.TrimSpace(l) != "" {
			out = append(out, l)
		}
	}
	return out
}

func fileContains(path, needle string) bool {
	b, err := os.ReadFile(path)
	return err == nil && strings.Contains(string(b), needle)
}

func parseEpoch(s string) int64 {
	n, _ := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	return n
}

func validShellName(s string) bool {
	if s == "" {
		return false
	}
	for i, c := range s {
		ok := (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' ||
			(i > 0 && c >= '0' && c <= '9')
		if !ok {
			return false
		}
	}
	return true
}

func exportAnswers(answers map[string]string) {
	for k, v := range answers {
		_ = os.Setenv(k, v)
	}
}

func persistInstallEnv(answers map[string]string) {
	home := os.Getenv("HOME")
	if home == "" {
		return
	}
	cfgDir := filepath.Join(home, ".config", "caelestia-kde")
	if err := os.MkdirAll(cfgDir, 0755); err != nil {
		return
	}
	var b strings.Builder
	for k, v := range answers {
		if !validShellName(k) {
			continue
		}
		fmt.Fprintf(&b, "%s='%s'\n", k, strings.ReplaceAll(v, "'", "'\\''"))
	}
	_ = os.WriteFile(filepath.Join(cfgDir, "install.env"), []byte(b.String()), 0644)
}

// prepareInstallEnv sets the environment the step scripts expect and (re)opens
// the shared install log.
func (m model) prepareInstallEnv() error {
	cache := m.cacheDir()
	_ = os.Setenv("CACHE_DIR", cache)
	_ = os.Setenv("BUILDDIR", filepath.Join(cache, "makepkg-build"))
	_ = os.Setenv("PKGDEST", filepath.Join(cache, "makepkg-packages"))
	_ = os.Setenv("SRCDEST", filepath.Join(cache, "makepkg-sources"))
	_ = os.Setenv("SRCPKGDEST", filepath.Join(cache, "makepkg-srcpackages"))

	for _, p := range []string{
		cache,
		filepath.Join(cache, "makepkg-build"),
		filepath.Join(cache, "makepkg-packages"),
		filepath.Join(cache, "makepkg-sources"),
		filepath.Join(cache, "makepkg-srcpackages"),
	} {
		if err := os.MkdirAll(p, 0755); err != nil {
			return err
		}
	}
	_ = os.Remove(filepath.Join(cache, "failed_steps.txt"))
	_ = os.Remove(filepath.Join(cache, "failed_packages.txt"))
	_ = os.Remove(filepath.Join(cache, "failed_patches.txt"))

	_ = os.Setenv("BASE_DISTRO", m.baseDistro)
	_ = os.Setenv("BUNDLE_DIR", m.bundleDir)

	path := os.Getenv("PATH")
	if path == "" {
		path = "/usr/bin"
	}
	if m.sudoBinDir != "" {
		_ = os.Setenv("PATH", m.sudoBinDir+":"+path)
	}
	_ = os.Setenv("CONFIRM_ARG", "--noconfirm")

	f, err := os.OpenFile(m.installLogPath(), os.O_WRONLY|os.O_CREATE|os.O_TRUNC|os.O_APPEND, 0644)
	if err != nil {
		return err
	}
	return f.Close()
}

// startStep begins step i (or skips it) and returns a Cmd that reports
// completion. Output streams to the shared install log, never the terminal.
func (m model) startStep(i int) (model, tea.Cmd) {
	ins := m.install
	steps := m.cfg.Manifest.Steps
	if len(steps) > 0 {
		ins.progress.SetWidth(progressBarWidth(m.width))
	}

	if stepIsSkipped(steps[i], m.answers) {
		ins.statuses[i] = statusSkipped
		ins.current = i
		return m.advanceStep()
	}

	ins.statuses[i] = statusRunning
	ins.current = i
	ins.running = true
	ins.dialog = false
	ins.stepStart = time.Now()
	ins.liveLines = nil

	if st, err := os.Stat(ins.logPath); err == nil {
		ins.stepStartOffset = st.Size()
	}
	if f, err := os.OpenFile(ins.logPath, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644); err == nil {
		fmt.Fprintf(f, "\n[CAELESTIA] %s\n", steps[i].Name)
		f.Close()
	}

	script := filepath.Join(m.bundleDir, steps[i].Script)
	cmd := exec.Command("bash", script)
	logf, err := os.OpenFile(ins.logPath, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644)
	if err == nil {
		cmd.Stdout = logf
		cmd.Stderr = logf
	} else {
		cmd.Stdout = os.Stderr
		cmd.Stderr = os.Stderr
	}

	if err := cmd.Start(); err != nil {
		if logf != nil {
			logf.Close()
		}
		return m, func() tea.Msg { return stepFinishedMsg{exitCode: 127, startFailed: true} }
	}
	ins.cmd = cmd

	waitCmd := func() tea.Msg {
		werr := cmd.Wait()
		if logf != nil {
			logf.Close()
		}
		code := 0
		if werr != nil {
			if ee, ok := werr.(*exec.ExitError); ok {
				code = ee.ExitCode()
			} else {
				code = 127
			}
		}
		return stepFinishedMsg{exitCode: code}
	}
	return m, tea.Batch(ins.setProgressTarget(len(steps)), waitCmd)
}

func (ins *installState) setProgressTarget(total int) tea.Cmd {
	if ins == nil || total < 1 {
		return nil
	}
	target := float64(ins.current) / float64(total)
	if ins.progress.Percent() == target {
		return nil
	}
	return ins.progress.SetPercent(target)
}

func (m model) advanceStep() (model, tea.Cmd) {
	ins := m.install
	ins.current++
	if ins.current >= len(m.cfg.Manifest.Steps) {
		ins.finished = true
		return m.enterComplete()
	}
	return m.startStep(ins.current)
}

func (m model) enterComplete() (model, tea.Cmd) {
	cache := m.cacheDir()
	m.complete = &completeState{
		logPath:     filepath.Join(cache, "install.log"),
		startEpoch:  parseEpoch(os.Getenv("INSTALL_START_EPOCH")),
		failedPkgs:  readLines(filepath.Join(cache, "failed_packages.txt")),
		shellFailed: fileContains(filepath.Join(cache, "failed_steps.txt"), "Build Caelestia Shell"),
	}
	m.screen = screenComplete
	return m, nil
}

// refreshLog re-reads the tail of the log into the log view state.
func (m *model) refreshLog() {
	if m.logView == nil {
		return
	}
	content := readLogTailBytes(m.logView.logPath, 1024*1024)
	lines := strings.Split(content, "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	out := make([]string, len(lines))
	issues := make([]int, 0, 8)
	for i, l := range lines {
		out[i] = stripANSI(l)
		if hasIssue(l) {
			issues = append(issues, i)
		}
	}
	m.logView.lines = out
	m.logView.issues = issues
}

// refreshLive tails only the running step's own log segment into the model so
// the Install screen shows live output without noise from earlier steps.
func (m *model) refreshLive() {
	ins := m.install
	if ins == nil || !ins.running {
		return
	}
	lines := strings.Split(readLogDelta(ins.logPath, ins.stepStartOffset), "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	out := make([]string, len(lines))
	for i, l := range lines {
		out[i] = stripANSI(l)
	}
	if len(out) > 40 {
		out = out[len(out)-40:]
	}
	ins.liveLines = out
}
