// Tiny HTTP service used as the artifact we sign, attest and verify.
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

var version = "dev"

func handler(w http.ResponseWriter, _ *http.Request) {
	fmt.Fprintf(w, "hello from signed-by-default %s\n", version)
}

func main() {
	http.HandleFunc("/", handler)
	addr := ":" + getenv("PORT", "8080")
	log.Printf("listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

func getenv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
