//go:build windows

package runner

import "syscall"

// detachedSysProcAttr is a no-op on Windows; systemd-inhibit never runs there.
func detachedSysProcAttr() *syscall.SysProcAttr {
	return nil
}
