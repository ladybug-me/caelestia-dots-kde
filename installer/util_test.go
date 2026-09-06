package main

import "testing"

func TestFit(t *testing.T) {
	cases := []struct {
		in   string
		max  int
		want string
	}{
		{"hello", 10, "hello"},
		{"hello", 5, "hello"},
		{"hello", 4, "h..."},
		{"hello", 3, "hel"},
		{"hello", 0, ""},
	}
	for _, c := range cases {
		if got := fit(c.in, c.max); got != c.want {
			t.Errorf("fit(%q, %d) = %q, want %q", c.in, c.max, got, c.want)
		}
	}
}

func TestStripANSI(t *testing.T) {
	in := "\x1b[31mred\x1b[0m and \x1b[1;32mbold green\x1b[0m"
	if got := stripANSI(in); got != "red and bold green" {
		t.Errorf("stripANSI = %q", got)
	}
}

func TestMarkers(t *testing.T) {
	if !containsWarn("line\n[WARN] something\n") {
		t.Error("containsWarn should detect [WARN]")
	}
	if containsWarn("clean output") {
		t.Error("containsWarn should not match clean output")
	}
	if !hasIssue("[ERR] boom") {
		t.Error("hasIssue should detect [ERR]")
	}
}
