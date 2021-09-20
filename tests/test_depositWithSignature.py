import brownie
from brownie import web3
from eth_account import Account, messages


def generate_signature(receiver_account, amounts, signer):
    keccak_hex = web3.solidityKeccak(
        ['address', 'uint256[3]'],
        [receiver_account.address, amounts]
    ).hex()
    message_to_sign = messages.encode_defunct(hexstr=keccak_hex)
    signature = Account.sign_message(message_to_sign, private_key=signer.private_key)
    signature_hex = signature.signature.hex()
    return signature_hex


def test_deposit_with_signature(token, swapContract, accounts):
    account = accounts[2]
    amounts = [10, 30, 50]
    signature = generate_signature(account, amounts, accounts[-1])

    token.mint(
        account,
        1000
    )

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )

    swapContract.depositWithSignature(
        100,
        account,
        account,
        amounts,
        signature,
        {'from': account}
    )

    assert token.balanceOf(account) == 910


def test_insufficient_balance(token, swapContract, accounts):
    account = accounts[2]
    amounts = [10, 30, 50]
    signature = generate_signature(account, amounts, accounts[-1])

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )
    with brownie.reverts('swapContract: Insufficient balance'):
        swapContract.depositWithSignature(
            100,
            account,
            account,
            amounts,
            signature,
            {'from': account}
        )


def test_min_amount(token, swapContract, accounts):
    account = accounts[2]
    amounts = [10, 30, 50]
    signature = generate_signature(account, amounts, accounts[-1])

    token.mint(
        account,
        1000
    )

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )
    with brownie.reverts('swapContract: Less than required minimum of tokens requested'):
        swapContract.depositWithSignature(
            10,
            account,
            account,
            amounts,
            signature,
            {'from': account}
        )


def test_max_amount(token, swapContract, accounts):
    account = accounts[2]
    amounts = [1000, 3000, 5000]
    signature = generate_signature(account, amounts, accounts[-1])

    token.mint(
        account,
        10000
    )

    token.approve(
        swapContract.address,
        10000,
        {'from': account}
    )
    with brownie.reverts():
        swapContract.depositWithSignature(
            2000,
            account,
            account,
            amounts,
            signature,
            {'from': account}
        )


def test_invalid_sender(token, swapContract, accounts):
    account = accounts[2]
    amounts = [10, 30, 50]
    account_to_sign = accounts[3]
    signature = generate_signature(account_to_sign, amounts, accounts[-1])

    token.mint(
        account,
        1000
    )

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )
    with brownie.reverts():
        swapContract.depositWithSignature(
            100,
            account,
            account_to_sign,
            amounts,
            signature,
            {'from': account}
        )


def test_swap_limits_saved(token, swapContract, accounts):
    account = accounts[2]
    amounts = [10, 30, 50]
    signature = generate_signature(account, amounts, accounts[-1])

    token.mint(
        account,
        1000
    )

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )

    swapContract.depositWithSignature(
        20,
        account,
        account,
        amounts,
        signature,
        {'from': account}
    )

    assert token.balanceOf(account) == 980

    with brownie.reverts():
        swapContract.depositWithSignature(
            20,
            account,
            account,
            amounts,
            signature,
            {'from': account}
        )


def test_invalid_validator(token, swapContract, accounts):
    account = accounts[2]
    amounts = [10, 30, 50]

    signature = generate_signature(account, amounts, accounts[-2])

    token.mint(
        account,
        1000
    )

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )
    with brownie.reverts():
        swapContract.depositWithSignature(
            100,
            account,
            account,
            amounts,
            signature,
            {'from': account}
        )


def test_swap_limit_reached(token, swapContract, accounts):
    account = accounts[2]
    amounts = [10, 30, 50]
    signature = generate_signature(account, amounts, accounts[-1])

    token.mint(
        account,
        1000
    )

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )

    swapContract.depositWithSignature(
        90,
        account,
        account,
        amounts,
        signature,
        {'from': account}
    )

    assert token.balanceOf(account) == 910

    with brownie.reverts():
        swapContract.depositWithSignature(
            90,
            account,
            account,
            amounts,
            signature,
            {'from': account}
        )


def test_amount_to_receive_is_zero(token, swapContract, accounts):
    account = accounts[2]
    amounts = [0, 2, 4]
    signature = generate_signature(account, amounts, accounts[-1])

    token.mint(
        account,
        1000
    )

    token.approve(
        swapContract.address,
        1000,
        {'from': account}
    )

    with brownie.reverts():
        swapContract.depositWithSignature(
            100,
            account,
            account,
            amounts,
            signature,
            {'from': account}
        )
