import pytest


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    # perform a chain rewind after completing each test, to ensure proper isolation
    # https://eth-brownie.readthedocs.io/en/v1.10.3/tests-pytest-intro.html#isolation-fixtures
    pass


@pytest.fixture(scope="module")
def token(Token, accounts):
    return Token.deploy(
        "Token",
        "TOKEN",
        1_000_000,
        0,
        {'from': accounts[0]})


@pytest.fixture(scope="module")
def swapContract(SwapContract, token, accounts):
    accounts.add('0xaf0eb7e81bb006606dda456218665a08feb04abfda14e16f938eeb70641a768f')
    accounts.add('0x3148d9d362f20e02e7b0b169bc0169897ce889890ac8b5be08813db91b1f311d')
    return SwapContract.deploy(
        token.address,
        accounts[-1],
        [1, 3, 5],
        [True, True, True],
        20,
        1000,
        {'from': accounts[0]})
