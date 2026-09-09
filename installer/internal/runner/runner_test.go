package runner

import "testing"

func TestMarkers(t *testing.T) {
	if !ContainsWarn("line\n[WARN] something\n") {
		t.Error("ContainsWarn should detect [WARN]")
	}
	if ContainsWarn("clean output") {
		t.Error("ContainsWarn should not match clean output")
	}
	if !HasIssue("[ERR] boom") {
		t.Error("HasIssue should detect [ERR]")
	}
}
