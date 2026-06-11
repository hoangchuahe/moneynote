package main

import "testing"

func TestListenAddr(t *testing.T) {
	if got := listenAddr(""); got != ":8080" {
		t.Fatalf("default addr = %q, want :8080", got)
	}
	if got := listenAddr("9090"); got != ":9090" {
		t.Fatalf("addr = %q, want :9090", got)
	}
}
