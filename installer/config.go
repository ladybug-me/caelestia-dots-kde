package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Theme mirrors installer/theme.json.
type Theme struct {
	Palette map[string]string `json:"palette"`
	Colors  map[string]string `json:"colors"`
	Splash  struct {
		Art      []string `json:"art"`
		Author   string   `json:"author"`
		CoAuthor string   `json:"co_author"`
		ArtColor string   `json:"art_color"`
	} `json:"splash_screen"`
	Glyphs map[string]string `json:"glyphs"`
}

// MenuItem mirrors one entry in installer/menu.json.
type MenuItem struct {
	ID      string     `json:"id"`
	Type    string     `json:"type"`
	Title   string     `json:"title"`
	Help    string     `json:"help"`
	Default any        `json:"default"`
	Options []string   `json:"options"`
	Items   []MenuItem `json:"items"`
}

// Menu mirrors installer/menu.json.
type Menu struct {
	Menu []MenuItem `json:"menu"`
}

// Phase and Step mirror installer/steps.json.
type Phase struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// Step is one unit of install work backed by a single script in scripts/.
type Step struct {
	Name   string `json:"name"`
	Script string `json:"script"`
	Phase  string `json:"phase"`
}

// StepsManifest mirrors installer/steps.json.
type StepsManifest struct {
	Phases []Phase `json:"phases"`
	Steps  []Step  `json:"steps"`
}

// config bundles the three installer JSON files plus resolved glyphs.
type config struct {
	Theme    Theme
	Menu     Menu
	Manifest StepsManifest
	Palette  map[string]string
	Glyphs   map[string]string
}

func loadJSON(path string, out any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, out)
}

func loadConfig(bundleDir string) (*config, error) {
	cfg := &config{
		Palette: map[string]string{},
		Glyphs:  defaultGlyphs(),
	}

	if err := loadJSON(filepath.Join(bundleDir, "installer", "theme.json"), &cfg.Theme); err == nil {
		for name, v := range cfg.Theme.Palette {
			cfg.Palette[name] = v
		}
		if len(cfg.Palette) == 0 {
			for name, v := range cfg.Theme.Colors {
				cfg.Palette[name] = v
			}
		}
		for name, v := range cfg.Theme.Glyphs {
			if strings.TrimSpace(v) != "" {
				cfg.Glyphs[name] = v
			}
		}
	}

	// The menu is optional; a bundle without it skips the configure phase.
	_ = loadJSON(filepath.Join(bundleDir, "installer", "menu.json"), &cfg.Menu)

	if err := loadJSON(filepath.Join(bundleDir, "installer", "steps.json"), &cfg.Manifest); err != nil {
		return nil, err
	}

	return cfg, nil
}

func defaultGlyphs() map[string]string {
	return map[string]string{
		"pending":      "[ ]",
		"running":      "[>]",
		"ok":           "[OK]",
		"warn":         "[WARN]",
		"failed":       "[ERR]",
		"skipped":      "[SKIP]",
		"checkbox_on":  "[x]",
		"checkbox_off": "[ ]",
		"select_left":  "<",
		"select_right": ">",
	}
}

func hexToRGB(s string) (int, int, int, bool) {
	if len(s) != 7 || s[0] != '#' {
		return 0, 0, 0, false
	}
	n, err := strconv.ParseUint(s[1:], 16, 32)
	if err != nil {
		return 0, 0, 0, false
	}
	return int(n>>16) & 0xff, int(n>>8) & 0xff, int(n) & 0xff, true
}
