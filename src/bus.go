package main

import (
	"fmt"
	"time"

	log "github.com/Sirupsen/logrus"
	"github.com/nats-io/nats"
)

var busTimeout = time.Duration(BusTimeout) * time.Second
var natsOpts = nats.DefaultOptions
var natsConn *nats.Conn

// initNatsBus initialize the NATS bus options
func initNatsBus(addr string) {
	log.WithFields(log.Fields{
		"nats": addr,
	}).Debug("initializing NATS bus")
	natsOpts.Servers = []string{addr}
}

// openNatsBus connect to the NATS bus
func openNatsBus() (err error) {
	log.WithFields(log.Fields{
		"nats": natsOpts.Servers,
	}).Debug("opening NATS bus connection")
	natsConn, err = natsOpts.Connect()
	if err != nil {
		return fmt.Errorf("Can't connect to the NATS bus: %v", err)
	}
	return nil
}

// closeNatsBus close the NATS bus
func closeNatsBus() {
	log.WithFields(log.Fields{
		"nats": natsOpts.Servers,
	}).Debug("closing NATS bus connection")
	natsConn.Flush()
	natsConn.Close()
}

// checkNatsBus check if the NATS bus is alive
func checkNatsBus() (err error) {
	err = openNatsBus()
	if err == nil {
		closeNatsBus()
	}
	return err
}
