// Package util holds small OS/string helpers with no UI or config dependency.
package util

import (
	"os"
	"path/filepath"
	"strings"
)

// Fit truncates s to max runes, appending "..." when it overflows.
func Fit(s string, max int) string {
	if max <= 0 {
		return ""
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	if max <= 3 {
		return string(r[:max])
	}
	return string(r[:max-3]) + "..."
}

// StripANSI removes ANSI escape sequences from s.
func StripANSI(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	runes := []rune(s)
	for i := 0; i < len(runes); i++ {
		c := runes[i]
		if c == 0x1b {
			if i+1 < len(runes) && runes[i+1] == '[' {
				i += 2
				for i < len(runes) {
					f := runes[i]
					if (f >= 'A' && f <= 'Z') || (f >= 'a' && f <= 'z') || f == '~' {
						break
					}
					i++
				}
			} else if i+1 < len(runes) && runes[i+1] == ']' {
				i += 2
				for i < len(runes) && runes[i] != 0x07 {
					i++
				}
			} else if i+1 < len(runes) {
				i++
			}
			continue
		}
		b.WriteRune(c)
	}
	return b.String()
}

// DistroLabel maps a BASE_DISTRO id to a human-readable label.
func DistroLabel(id string) string {
	switch id {
	case "arch":
		return "Arch-based Linux"
	case "fedora":
		return "Fedora"
	case "debian":
		return "Debian-based Linux"
	}
	if id == "" {
		return "unknown"
	}
	return id
}

// IsCaelestiaInstalled reports whether the caelestia CLI is already on PATH
// (or in the usual well-known locations), used to decide whether to offer
// Update/Uninstall alongside Install.
func IsCaelestiaInstalled() bool {
	executable := func(p string) bool {
		fi, err := os.Stat(p)
		return err == nil && !fi.IsDir() && fi.Mode()&0111 != 0
	}
	if home, err := os.UserHomeDir(); err == nil {
		if executable(filepath.Join(home, ".local", "bin", "caelestia")) {
			return true
		}
	}
	if executable("/usr/local/bin/caelestia") || executable("/usr/bin/caelestia") {
		return true
	}
	for _, dir := range filepath.SplitList(os.Getenv("PATH")) {
		if dir != "" && executable(filepath.Join(dir, "caelestia")) {
			return true
		}
	}
	return false
}
