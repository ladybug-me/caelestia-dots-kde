package util

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
		if got := Fit(c.in, c.max); got != c.want {
			t.Errorf("Fit(%q, %d) = %q, want %q", c.in, c.max, got, c.want)
		}
	}
}

func TestStripANSI(t *testing.T) {
	in := "\x1b[31mred\x1b[0m and \x1b[1;32mbold green\x1b[0m"
	if got := StripANSI(in); got != "red and bold green" {
		t.Errorf("StripANSI = %q", got)
	}
}
