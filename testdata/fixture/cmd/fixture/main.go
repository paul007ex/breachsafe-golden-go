// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

// Command fixture exists so the GOFIPS140 gate has a real binary to inspect:
// `go version -m` can only report build settings for a linked executable.
package main

import (
	"fmt"

	"fixture"
)

func main() {
	if err := fixture.SignAndVerify([]byte("fixture")); err != nil {
		panic(err)
	}
	fmt.Println("ok")
}
