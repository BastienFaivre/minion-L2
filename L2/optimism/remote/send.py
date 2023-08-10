#!/usr/bin/env python3
#===============================================================================
# Description: Send ETH from private account to another account
#===============================================================================
from web3 import Web3, HTTPProvider
from eth_account import Account
import sys

def send_transaction(node_url, chain_id, private_key, to_address, amount):
    web3 = Web3(HTTPProvider(node_url))
    account = Account.from_key(private_key)
    balance = web3.eth.get_balance(account.address)
    gas_price = web3.eth.gas_price
    gas = 21000
    if balance < (gas_price * gas) + web3.to_wei(amount, 'ether'):
        print('Insufficient funds')
        print('balance: ' + str(balance))
        print('gas_price: ' + str(gas_price))
        print('gas: ' + str(gas))
        print('amount (wei): ' + str(web3.to_wei(amount, 'ether')))
        print('total cost (wei): ' + str((gas_price * gas) + web3.to_wei(amount, 'ether')))
        sys.exit(1)
    nonce = web3.eth.get_transaction_count(account.address, 'pending')
    to_address = web3.to_checksum_address(to_address)
    transaction = {
        'to': to_address,
        'value': web3.to_wei(amount, 'ether'),
        'gas': gas,
        'gasPrice': gas_price,
        'nonce': nonce,
        'chainId': chain_id
    }
    signed_transaction = account.sign_transaction(transaction)
    try:
        print((web3.eth.send_raw_transaction(signed_transaction.rawTransaction)).hex())
    except Exception as e:
        print(e)
        sys.exit(1)

if __name__ == '__main__':
    node_url = sys.argv[1]
    chain_id = int(sys.argv[2])
    private_key = sys.argv[3]
    to_address = sys.argv[4]
    amount = float(sys.argv[5])
    send_transaction(node_url, chain_id, private_key, to_address, amount)
