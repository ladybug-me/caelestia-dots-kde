package main

import (
	"os"
	"path/filepath"
	"strings"
)

// fit truncates s to max runes, appending "..." when it overflows.
func fit(s string, max int) string {
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

// stripANSI removes ANSI escape sequences from s.
func stripANSI(s string) string {
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

func distroLabel(id string) string {
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

func isCaelestiaInstalled() bool {
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
