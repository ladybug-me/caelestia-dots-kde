//go:build windows

package main

import "os"

// signalTerminate is only used at runtime on Linux; on Windows builds it is a
// best-effort fallback so the package still compiles for development.
func signalTerminate(p *os.Process) {
	if p == nil {
		return
	}
	_ = p.Kill()
}
