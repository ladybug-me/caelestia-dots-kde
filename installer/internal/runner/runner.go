// Package runner executes step scripts and manages the shared install log,
// install.env persistence, and the sudo/privilege environment they need.
package runner

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/util"
)

// Marker scanning contract: a step's own output segment is scanned for the
// literal [WARN] marker to promote OK to WARN; the live log view jumps to
// lines containing [WARN] or [ERR].
func ContainsWarn(s string) bool { return strings.Contains(s, "[WARN]") }

func HasIssue(s string) bool {
	return strings.Contains(s, "[WARN]") || strings.Contains(s, "[ERR]")
}

// CacheDir returns the installer's cache directory ($XDG_CACHE_HOME or
// ~/.cache, plus caelestia-kde).
func CacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "caelestia-kde")
}

// InstallLogPath returns the shared install log path under cacheDir.
func InstallLogPath(cacheDir string) string { return filepath.Join(cacheDir, "install.log") }

func ReadLogTailBytes(path string, maxBytes int64) string {
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

func ReadLogDelta(path string, startOffset int64) string {
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

func ReadLogTailLines(path string, maxLines int) []string {
	content := ReadLogTailBytes(path, 512*1024)
	var out []string
	for _, l := range strings.Split(content, "\n") {
		out = append(out, util.StripANSI(l))
	}
	if len(out) > maxLines {
		out = out[len(out)-maxLines:]
	}
	return out
}

func ReadLines(path string) []string {
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

func FileContains(path, needle string) bool {
	b, err := os.ReadFile(path)
	return err == nil && strings.Contains(string(b), needle)
}

func ParseEpoch(s string) int64 {
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

func ExportAnswers(answers map[string]string) {
	for k, v := range answers {
		_ = os.Setenv(k, v)
	}
}

func PersistInstallEnv(answers map[string]string) {
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

// LoadInstallEnv reads install.env's KEY='value' lines (written by
// PersistInstallEnv) so a later Update run can restore the install-time menu
// choices (default shell, lockscreen plugin, ...) that the deploy/tweak
// scripts would otherwise fall back to hardcoded defaults for.
func LoadInstallEnv() map[string]string {
	home := os.Getenv("HOME")
	if home == "" {
		return nil
	}
	b, err := os.ReadFile(filepath.Join(home, ".config", "caelestia-kde", "install.env"))
	if err != nil {
		return nil
	}
	out := map[string]string{}
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		key, val, ok := strings.Cut(line, "=")
		if !ok || !validShellName(key) {
			continue
		}
		val = strings.TrimSuffix(strings.TrimPrefix(val, "'"), "'")
		out[key] = strings.ReplaceAll(val, "'\\''", "'")
	}
	return out
}

// PrepareInstallEnv sets the environment the step scripts expect and (re)opens
// the shared install log.
func PrepareInstallEnv(cacheDir, baseDistro, bundleDir, sudoBinDir string) error {
	_ = os.Setenv("CACHE_DIR", cacheDir)
	_ = os.Setenv("BUILDDIR", filepath.Join(cacheDir, "makepkg-build"))
	_ = os.Setenv("PKGDEST", filepath.Join(cacheDir, "makepkg-packages"))
	_ = os.Setenv("SRCDEST", filepath.Join(cacheDir, "makepkg-sources"))
	_ = os.Setenv("SRCPKGDEST", filepath.Join(cacheDir, "makepkg-srcpackages"))

	for _, p := range []string{
		cacheDir,
		filepath.Join(cacheDir, "makepkg-build"),
		filepath.Join(cacheDir, "makepkg-packages"),
		filepath.Join(cacheDir, "makepkg-sources"),
		filepath.Join(cacheDir, "makepkg-srcpackages"),
	} {
		if err := os.MkdirAll(p, 0755); err != nil {
			return err
		}
	}
	_ = os.Remove(filepath.Join(cacheDir, "failed_steps.txt"))
	_ = os.Remove(filepath.Join(cacheDir, "failed_packages.txt"))
	_ = os.Remove(filepath.Join(cacheDir, "failed_patches.txt"))

	_ = os.Setenv("BASE_DISTRO", baseDistro)
	_ = os.Setenv("BUNDLE_DIR", bundleDir)

	path := os.Getenv("PATH")
	if path == "" {
		path = "/usr/bin"
	}
	if sudoBinDir != "" {
		_ = os.Setenv("PATH", sudoBinDir+":"+path)
	}
	_ = os.Setenv("CONFIRM_ARG", "--noconfirm")

	f, err := os.OpenFile(InstallLogPath(cacheDir), os.O_WRONLY|os.O_CREATE|os.O_TRUNC|os.O_APPEND, 0644)
	if err != nil {
		return err
	}
	return f.Close()
}

// StepHandle is a started step script; call Wait to block for completion and
// obtain its exit code.
type StepHandle struct {
	Cmd     *exec.Cmd
	logFile *os.File
}

// StartStep begins running step's script, streaming its output to logPath
// (never the installer's own terminal) and writing a marker line first.
func StartStep(bundleDir string, step config.Step, logPath string) (*StepHandle, error) {
	if f, err := os.OpenFile(logPath, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644); err == nil {
		fmt.Fprintf(f, "\n[CAELESTIA] %s\n", step.Name)
		f.Close()
	}

	script := filepath.Join(bundleDir, step.Script)
	cmd := exec.Command("bash", script)
	logf, err := os.OpenFile(logPath, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644)
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
		return nil, err
	}
	return &StepHandle{Cmd: cmd, logFile: logf}, nil
}

// Wait blocks for the step to finish and returns its exit code (127 if it
// could not be waited on).
func (h *StepHandle) Wait() int {
	err := h.Cmd.Wait()
	if h.logFile != nil {
		h.logFile.Close()
	}
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 127
	}
	return 0
}
