package main

import (
	"fmt"
	"io"
	"net"
	"os"
)

func main() {
	conn, err := net.Dial("tcp", "p1meter.dev:8080")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer conn.Close()

	fmt.Println("Connected to Smart Meter P1 Stream")

	// Raw telegram data (DSMR 5.0 format)
	io.Copy(os.Stdout, conn)
}
