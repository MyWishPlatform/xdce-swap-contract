import brownie


def test_owner(token, swapContract, accounts):
    limits = [10, 30, 50]
    account = accounts[0]
    swapContract.updateSwapLimits(account, limits, {'from': accounts[0]})
    assert swapContract.swapLimitsArray(account) == limits
    assert swapContract.swapLimitsSaved(account)


def test_validator(token, swapContract, accounts):
    limits = [10, 30, 50]
    account = accounts[0]
    swapContract.updateSwapLimits(account, limits, {'from': accounts[-1]})
    assert swapContract.swapLimitsArray(account) == limits
    assert swapContract.swapLimitsSaved(account)


def test_not_owner_or_validator(token, swapContract, accounts):
    with brownie.reverts('Caller is not in owner or validator role'):
        swapContract.updateSwapLimits(accounts[0], [10, 30, 50], {'from': accounts[1]})
