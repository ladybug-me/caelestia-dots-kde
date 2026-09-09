// Package config loads and represents the installer's bundle-relative JSON
// files: theme.json, menu.json, and steps.json.
package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// Theme mirrors installer/theme.json: a splash banner plus a light and dark
// palette (auto-selected at runtime from the terminal's background color).
type Theme struct {
	Splash struct {
		Art      []string `json:"art"`
		Author   string   `json:"author"`
		CoAuthor string   `json:"co_author"`
		ArtColor string   `json:"art_color"`
	} `json:"splash"`
	Palette struct {
		Dark  map[string]string `json:"dark"`
		Light map[string]string `json:"light"`
	} `json:"palette"`
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

// Config bundles the three installer JSON files.
type Config struct {
	Theme    Theme
	Menu     Menu
	Manifest StepsManifest
}

func loadJSON(path string, out any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, out)
}

// Load reads theme.json, menu.json, and steps.json from bundleDir/installer.
func Load(bundleDir string) (*Config, error) {
	cfg := &Config{}

	// theme.json and menu.json are optional: a bundle without them falls
	// back to the built-in palette, and skips the configure phase entirely.
	_ = loadJSON(filepath.Join(bundleDir, "installer", "theme.json"), &cfg.Theme)
	_ = loadJSON(filepath.Join(bundleDir, "installer", "menu.json"), &cfg.Menu)

	if err := loadJSON(filepath.Join(bundleDir, "installer", "steps.json"), &cfg.Manifest); err != nil {
		return nil, err
	}

	return cfg, nil
}

// LoadManifest reads a standalone steps manifest (e.g. update-steps.json or
// uninstall-steps.json, same shape as steps.json) from bundleDir/installer.
// Used to swap Config.Manifest when the Update/Uninstall flow starts.
func LoadManifest(bundleDir, filename string) (StepsManifest, error) {
	var m StepsManifest
	err := loadJSON(filepath.Join(bundleDir, "installer", filename), &m)
	return m, err
}
