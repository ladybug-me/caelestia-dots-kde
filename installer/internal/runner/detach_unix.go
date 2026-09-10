//go:build !windows

package runner

import "syscall"

// detachedSysProcAttr starts a process as its own session leader with no
// controlling terminal. Without this, a fallback polkit text agent can open
// /dev/tty and write its prompt directly over the Bubble Tea alt-screen.
func detachedSysProcAttr() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{Setsid: true}
}
