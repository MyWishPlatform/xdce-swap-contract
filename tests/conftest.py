#!/usr/bin/python3

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
        1_000_000 * (10 ** 18),
        18,
        {'from': accounts[0]})


@pytest.fixture(scope="module")
def swapContract(SwapContract, token, accounts):
    accounts.add('0xaf0eb7e81bb006606dda456218665a08feb04abfda14e16f938eeb70641a768f')
    return SwapContract.deploy(
        token.address,
        accounts[-1],
        [1, 3, 5],
        1000 * (10 ** 18),
        10 * (10 ** 18),
        [True, False, False],
        {'from': accounts[0]})
