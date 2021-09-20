import brownie


def test_default(token, swapContract, accounts):
    token.mint(
        swapContract.address,
        1000
    )

    swapContract.claimTokens(accounts[0], 1000)


def test_claim_all(token, swapContract, accounts):
    token.mint(
        swapContract.address,
        1000
    )

    swapContract.claimTokens(accounts[0], 0)
    assert token.balanceOf(accounts[0]) == 1000


def test_insufficient_balance(token, swapContract, accounts):
    token.mint(
        swapContract.address,
        50
    )
    with brownie.reverts():
        swapContract.claimTokens(accounts[0], 100)


def test_zero_balance(token, swapContract, accounts):
    with brownie.reverts():
        swapContract.claimTokens(accounts[0], 0)


def test_claim_not_owner(token, swapContract, accounts):
    token.mint(
        swapContract.address,
        1000
    )
    with brownie.reverts():
        swapContract.claimTokens(
            accounts[0],
            0,
            {'from': accounts[1]}
        )
