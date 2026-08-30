// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
package fixture

import (
	"crypto/hpke"
	"testing"
)

func TestSealOpen(t *testing.T) {
	kem, err := hpke.NewKEM(0x0042) // ML-KEM-1024
	if err != nil {
		t.Fatal(err)
	}
	k, err := kem.GenerateKey()
	if err != nil {
		t.Fatal(err)
	}
	ct, err := Seal(k.PublicKey(), []byte("info"), []byte("plaintext"))
	if err != nil {
		t.Fatal(err)
	}
	pt, err := hpke.Open(k, hpke.HKDFSHA384(), hpke.AES256GCM(), []byte("info"), ct)
	if err != nil {
		t.Fatal(err)
	}
	if string(pt) != "plaintext" {
		t.Fatalf("round trip mismatch: %q", pt)
	}
}

func TestSignAndVerify(t *testing.T) {
	if err := SignAndVerify([]byte("message")); err != nil {
		t.Fatal(err)
	}
}
