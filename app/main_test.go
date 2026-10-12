package main

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandler(t *testing.T) {
	rr := httptest.NewRecorder()
	handler(rr, httptest.NewRequest("GET", "/", nil))
	if !strings.Contains(rr.Body.String(), "signed-by-default") {
		t.Fatal(rr.Body.String())
	}
}
