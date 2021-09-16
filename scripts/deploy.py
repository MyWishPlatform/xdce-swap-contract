#!/usr/bin/python3
import os
from brownie import SwapContract, accounts, network, config


def main():
    dev = accounts.add(os.getenv('PRIVATE_KEY'))
    print(network.show_active())
    publish_source = True if os.getenv("ETHERSCAN_TOKEN") else False
    SwapContract.deploy(
        "0x8971e7eee417eeF06cD3111f890d5d159A248404",
        "0x3BD43f8E6DC042DDf462077ae4Fbcf955C714Ff9",
        [1, 3, 5],
        100_000 * (10 ** 18),
        0,
        [True, False, False],
        {"from": dev}, publish_source=publish_source)
