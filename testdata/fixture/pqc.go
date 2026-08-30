// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Fixture exercising the post-quantum surface the toolchain exists to build.
package fixture

import (
	"crypto/hpke"
	"crypto/mldsa"
	"errors"
)

// Seal wraps plaintext under ML-KEM-1024 + HKDF-SHA384 + AES-256-GCM.
func Seal(pub hpke.PublicKey, info, plaintext []byte) ([]byte, error) {
	return hpke.Seal(pub, hpke.HKDFSHA384(), hpke.AES256GCM(), info, plaintext)
}

// SignAndVerify round-trips an ML-DSA-87 signature.
func SignAndVerify(msg []byte) error {
	k, err := mldsa.GenerateKey(mldsa.MLDSA87())
	if err != nil {
		return err
	}
	sig, err := k.Sign(nil, msg, nil)
	if err != nil {
		return err
	}
	if err := mldsa.Verify(k.PublicKey(), msg, sig, nil); err != nil {
		return errors.Join(errors.New("ml-dsa verify"), err)
	}
	return nil
}
