#!/usr/bin/python3

import pytest
import brownie
from brownie import web3
from eth_account import Account, messages


def test_deposit_with_signature(token, swapContract, accounts):
    amounts = [
        100 * (10 ** 18),
        200 * (10 ** 18),
        300 * (10 ** 18)
    ]
    keccak_hex = web3.solidityKeccak(
        ['address', 'uint256[3]'],
        [accounts[2].address, amounts]
    ).hex()
    message_to_sign = messages.encode_defunct(hexstr=keccak_hex)
    signature = Account.sign_message(message_to_sign, private_key=accounts[-1].private_key)
    token.mint(accounts[2], 1000 * (10 ** 18))
    token.approve(swapContract.address, 1000 * (10 ** 18), {'from': accounts[2]})
    swapContract.depositWithSignature(
        100 * (10 ** 18),
        accounts[2],
        accounts[2],
        amounts,
        signature.signature.hex(),
        {'from': accounts[2]}
    )
    assert token.balanceOf(accounts[2]) == 900 * (10 ** 18)


def test_max_amount_exceeded(token, swapContract, accounts):
    amounts = [1000 * (10 ** 18), 2000 * (10 ** 18), 3000 * (10 ** 18)]
    keccak_hex = web3.solidityKeccak(
        ['address', 'uint256[3]'],
        [accounts[2].address, amounts]
    ).hex()
    message_to_sign = messages.encode_defunct(hexstr=keccak_hex)
    signature = Account.sign_message(message_to_sign, private_key=accounts[-1].private_key)
    token.mint(accounts[2], 10000 * (10 ** 18))
    token.approve(swapContract.address, 10000 * (10 ** 18), {'from': accounts[2]})
    with brownie.reverts():
        swapContract.depositWithSignature(
            10000 * (10 ** 18),
            accounts[2],
            accounts[2],
            amounts,
            signature.signature.hex(),
            {'from': accounts[2]}
        )
