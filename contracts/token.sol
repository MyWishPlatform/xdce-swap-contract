// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20
{

    uint8 private _decimals;
    uint256 public maxTotalSupply;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxTotalSupply,
        uint8 _decimalPlaces
    )
        ERC20(name, symbol)
    {
        _decimals = _decimalPlaces;
        maxTotalSupply = _maxTotalSupply;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external
    {
        require(
            totalSupply() + amount <= maxTotalSupply,
            "Token: Total supply will exceed max total supply"
        );
        _mint(to, amount);
    }
}