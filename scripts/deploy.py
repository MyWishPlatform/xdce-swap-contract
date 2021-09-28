#!/usr/bin/python3
import os
from brownie import SwapContract, accounts, network
from distutils.util import strtobool


def main():
    dev = accounts.add(os.getenv('PRIVATE_KEY'))
    print(network.show_active())
    publish_source = True if os.getenv("ETHERSCAN_TOKEN") else False
    decimals = int(os.getenv("TOKEN_DECIMALS"))
    from brownie.network.gas.strategies import GasNowScalingStrategy
    gas_strategy = GasNowScalingStrategy("standard", "fast", 1.2)
    deploy_args = [
        os.getenv("TOKEN_ADDRESS"),
        os.getenv("VALIDATOR_ADDRESS"),
        os.getenv("SWAP_RATIOS").split(','),
        [strtobool(limit) for limit in os.getenv("SWAP_ENABLED").split(',')],
        int(os.getenv("MIN_SWAP_AMOUNT_PER_TX")) * (10 ** decimals),
        int(os.getenv("MAX_SWAP_AMOUNT_PER_TX")) * (10 ** decimals),
        {"from": dev, 'gas_price': gas_strategy},
    ]
    print('Deploy args:\n', deploy_args)
    if input("Deploy SwapContract? y/[N]: ").lower() != "y":
        return

    contract = SwapContract.deploy(
       *deploy_args, publish_source=publish_source
    )
    print('Deployed contract', contract.address)
