package main

import (
	"crypto/rand"
	"encoding/hex"
	"flag"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/peer"
)

func main() {
	privKeyPath := flag.String("privKeyPath", "", "Private Key File Path")
	peerIDPath := flag.String("peerIDPath", "", "Peer ID File Path")
	flag.Parse()

	priv, _, err := crypto.GenerateSecp256k1Key(rand.Reader)
	if err != nil {
		fmt.Printf("Failed to generate private key: %v\n", err)
		os.Exit(1)
	}

	privBytes, err := priv.Raw()
	if err != nil {
		fmt.Printf("Failed to get raw private key: %v\n", err)
		os.Exit(1)
	}

	err = ioutil.WriteFile(*privKeyPath, []byte(hex.EncodeToString(privBytes)), 0600)
	if err != nil {
		fmt.Printf("Failed to write private key to file: %v\n", err)
		os.Exit(1)
	}

	pid, err := peer.IDFromPrivateKey(priv)
	if err != nil {
		fmt.Printf("Failed to create peer ID from private key: %v\n", err)
		os.Exit(1)
	}

	err = ioutil.WriteFile(*peerIDPath, []byte(pid.Pretty()), 0600)
	if err != nil {
		fmt.Printf("Failed to write peer ID to file: %v\n", err)
		os.Exit(1)
	}
}
