package main

import (
	"fmt"
	"os"
	"testing"

	"github.com/spf13/viper"
)

func TestGetConfigParams(t *testing.T) {

	// load a specific config file just for testing
	oldCfg := ConfigPath
	viper.Reset()
	ConfigPath[0] = "../resources/test/etc/natsping/"
	ConfigPath[1] = "wrong/path/1/"
	ConfigPath[2] = "wrong/path/2/"
	ConfigPath[3] = "wrong/path/3/"
	ConfigPath[4] = "wrong/path/4/"
	defer func() { ConfigPath = oldCfg }()

	prm, err := getConfigParams()
	if err != nil {
		t.Error(fmt.Errorf("An error was not expected: %v", err))
	}
	if prm.natsAddress != "nats://127.0.0.1:4222" {
		t.Error(fmt.Errorf("Found different natsAddress than expected"))
	}
	if prm.logLevel != "DEBUG" {
		t.Error(fmt.Errorf("Found different logLevel than expected"))
	}
}

func TestGetLocalConfigParams(t *testing.T) {

	// test environment variables
	defer unsetRemoteConfigEnv()
	os.Setenv("NATSPING_REMOTECONFIGPROVIDER", "consul")
	os.Setenv("NATSPING_REMOTECONFIGENDPOINT", "127.0.0.1:98765")
	os.Setenv("NATSPING_REMOTECONFIGPATH", "/config/natsping")
	os.Setenv("NATSPING_REMOTECONFIGSECRETKEYRING", "")

	// load a specific config file just for testing
	oldCfg := ConfigPath
	viper.Reset()
	ConfigPath[0] = "../resources/test/etc/natsping/"
	ConfigPath[1] = "wrong/path/1/"
	ConfigPath[2] = "wrong/path/2/"
	ConfigPath[3] = "wrong/path/3/"
	ConfigPath[4] = "wrong/path/4/"
	defer func() { ConfigPath = oldCfg }()

	prm, rprm := getLocalConfigParams()

	if prm.natsAddress != "nats://127.0.0.1:4222" {
		t.Error(fmt.Errorf("Found different natsAddress than expected"))
	}
	if prm.logLevel != "DEBUG" {
		t.Error(fmt.Errorf("Found different logLevel than expected"))
	}
	if rprm.remoteConfigProvider != "consul" {
		t.Error(fmt.Errorf("Found different remoteConfigProvider than expected"))
	}
	if rprm.remoteConfigEndpoint != "127.0.0.1:98765" {
		t.Error(fmt.Errorf("Found different remoteConfigEndpoint than expected"))
	}
	if rprm.remoteConfigPath != "/config/natsping" {
		t.Error(fmt.Errorf("Found different remoteConfigPath than expected"))
	}
	if rprm.remoteConfigSecretKeyring != "" {
		t.Error(fmt.Errorf("Found different remoteConfigSecretKeyring than expected"))
	}

	_, err := getRemoteConfigParams(prm, rprm)
	if err == nil {
		t.Error(fmt.Errorf("A remote configuration error was expected"))
	}

	rprm.remoteConfigSecretKeyring = "/etc/natsping/cfgkey.gpg"
	_, err = getRemoteConfigParams(prm, rprm)
	if err == nil {
		t.Error(fmt.Errorf("A remote configuration error was expected"))
	}
}

// Test real Consul provider
// To activate this define the environmental variable NATSPING_LIVECONSUL
func TestGetConfigParamsRemote(t *testing.T) {

	enable := os.Getenv("NATSPING_LIVECONSUL")
	if enable == "" {
		return
	}

	// test environment variables
	defer unsetRemoteConfigEnv()
	os.Setenv("NATSPING_REMOTECONFIGPROVIDER", "consul")
	os.Setenv("NATSPING_REMOTECONFIGENDPOINT", "127.0.0.1:8500")
	os.Setenv("NATSPING_REMOTECONFIGPATH", "/config/natsping")
	os.Setenv("NATSPING_REMOTECONFIGSECRETKEYRING", "")

	// load a specific config file just for testing
	oldCfg := ConfigPath
	viper.Reset()
	ConfigPath[0] = "wrong/path/0/"
	ConfigPath[1] = "wrong/path/1/"
	ConfigPath[2] = "wrong/path/2/"
	ConfigPath[3] = "wrong/path/3/"
	ConfigPath[4] = "wrong/path/4/"
	defer func() { ConfigPath = oldCfg }()

	prm, err := getConfigParams()
	if err != nil {
		t.Error(fmt.Errorf("Unexpected error: %v", err))
	}
	if prm.natsAddress != "nats://127.0.0.1:4222" {
		t.Error(fmt.Errorf("Found different natsAddress than expected"))
	}
	if prm.logLevel != "DEBUG" {
		t.Error(fmt.Errorf("Found different logLevel than expected"))
	}
}

// unsetRemoteConfigEnv clear the environmental variables used to set the remote configuration
func unsetRemoteConfigEnv() {
	os.Setenv("NATSPING_REMOTECONFIGPROVIDER", "")
	os.Setenv("NATSPING_REMOTECONFIGENDPOINT", "")
	os.Setenv("NATSPING_REMOTECONFIGPATH", "")
	os.Setenv("NATSPING_REMOTECONFIGSECRETKEYRING", "")
}