//go:build !windows

package runner

import (
	"os"
	"syscall"
)

// SignalTerminate asks the step process to stop. On Linux we send SIGTERM,
// matching the C++ installer's kill(child, SIGTERM) behavior.
func SignalTerminate(p *os.Process) {
	if p == nil {
		return
	}
	_ = p.Signal(syscall.SIGTERM)
}
