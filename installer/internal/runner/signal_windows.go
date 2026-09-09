//go:build windows

package runner

import "os"

// SignalTerminate is only used at runtime on Linux; on Windows builds it is a
// best-effort fallback so the package still compiles for development.
func SignalTerminate(p *os.Process) {
	if p == nil {
		return
	}
	_ = p.Kill()
}
