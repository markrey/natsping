package main

import (
	"fmt"
	"os"
	"reflect"
	"testing"
)

var wrongParamCases = []string{
	"--natsAddress=",
	"--logLevel=",
	"--logLevel=INVALID",
}

func TestCliWrongParamError(t *testing.T) {
	for _, param := range wrongParamCases {
		os.Args = []string{ProgramName, param}
		cmd, err := cli()
		if err != nil {
			t.Error(fmt.Errorf("An error wasn't expected: %v", err))
			return
		}
		if cmdtype := reflect.TypeOf(cmd).String(); cmdtype != "*cobra.Command" {
			t.Error(fmt.Errorf("The expected type is '*cobra.Command', found: '%s'", cmdtype))
			return
		}

		old := os.Stderr // keep backup of the real stdout
		defer func() { os.Stderr = old }()
		os.Stderr = nil

		// execute the main function
		if err := cmd.Execute(); err == nil {
			t.Error(fmt.Errorf("An error was expected"))
		}
	}
}

func TestCliNoConfigError(t *testing.T) {
	os.Args = []string{ProgramName, "--natsAddress=nats://127.0.0.1:3334", "--configDir=wrong"}
	cmd, err := cli()
	if err != nil {
		t.Error(fmt.Errorf("An error wasn't expected: %v", err))
		return
	}
	if cmdtype := reflect.TypeOf(cmd).String(); cmdtype != "*cobra.Command" {
		t.Error(fmt.Errorf("The expected type is '*cobra.Command', found: '%s'", cmdtype))
		return
	}

	old := os.Stderr // keep backup of the real stdout
	defer func() { os.Stderr = old }()
	os.Stderr = nil

	oldCfg := ConfigPath
	for k := range ConfigPath {
		ConfigPath[k] = "wrong/path/"
	}
	defer func() {
		ConfigPath = oldCfg
	}()

	// execute the main function
	if err := cmd.Execute(); err == nil {
		t.Error(fmt.Errorf("An error was expected"))
	}
}
