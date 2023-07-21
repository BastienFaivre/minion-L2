#!/usr/bin/env python3
#===============================================================================
# Description: Extracts the private key from a keystore file
# Source: https://github.com/Blockchain-Benchmarking/minion/blob/cleanup/script/remote/linux/apt/install-geth-accounts-worker
#===============================================================================

import binascii
import sys
from web3.auto import w3
keypath = sys.argv[1]
password = sys.argv[2]
with open(keypath) as keyfile:
    encrypted_key = keyfile.read()
    private_key = w3.eth.account.decrypt(encrypted_key, password)
    formatted_key = binascii.b2a_hex(private_key).decode('ascii')
    print(formatted_key)