// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";


contract SwapContract is AccessControlEnumerable
{

    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    IERC20 public tokenAddress;
    mapping(address => bool) public swapLimitsSaved;
    mapping(address => uint256 [3]) swapLimits;
    uint256 public maxSwapAmountPerTx;
    uint256 public minSwapAmountPerTx;
    uint128 [3] public swapRatios;
    bool [3] public swapEnabled;

    event Deposit(address user, uint256 amount, uint256 amountToReceive, address newAddress);
    event TokensClaimed(address recipient, uint256 amount);

    /**
      * @dev throws if transaction sender is not in owner role
      */
    modifier onlyOwner() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Caller is not in owner role"
        );
        _;
    }

    /**
      * @dev Constructor of contract
      * @param _tokenAddress address Address of token contract
      */
    constructor(
        IERC20 _tokenAddress,
        address validatorAddress,
        uint128 [3] memory _swapRatios,
        uint256 _maxSwapAmountPerTx,
        uint256 _minSwapAmountPerTx,
        bool [3] memory _swapEnabled
    )
    {
        swapRatios = _swapRatios;
        swapEnabled = _swapEnabled;
        maxSwapAmountPerTx = _maxSwapAmountPerTx;
        minSwapAmountPerTx = _minSwapAmountPerTx;
        tokenAddress = _tokenAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(VALIDATOR_ROLE, validatorAddress);
    }

    function depositWithSignature(
        uint256 amountToSend,
        address newAddress,
        address signedAddress,
        uint256 [3] memory signedAmounts,
        bytes memory signature
    ) external
    {
        address sender = _msgSender();
        uint256 senderBalance = tokenAddress.balanceOf(sender);
        require(senderBalance >= amountToSend, "swapContract: Not enough balance");
        require(amountToSend >= minSwapAmountPerTx, "swapContract: Less than required minimum of tokens requested");
        require(amountToSend <= maxSwapAmountPerTx, "swapContract: Swap limit per transaction exceeded");
        require(sender == signedAddress, "swapContract: Signed and sender address does not match");
        require(!swapLimitsSaved[sender], "swapContract: Swap limits already saved");

        bytes32 hashedParams = keccak256(abi.encodePacked(signedAddress, signedAmounts));
        address validatorAddress = ECDSA.recover(ECDSA.toEthSignedMessageHash(hashedParams), signature);
        require(isValidator(validatorAddress), "swapContract: Invalid swap limits validator");

        (uint256[3] memory swapLimitsNew, uint256 amountToPay, uint256 amountToReceive) = calculateAmountsAfterSwap(
            signedAmounts, amountToSend, true
        );
        require(amountToPay > 0, "swapContract: Swap limit reached");
        require(amountToReceive > 0, "swapContract: Amount to receive is zero");

        swapLimits[signedAddress] = swapLimitsNew;
        swapLimitsSaved[sender] = true;

        TransferHelper.safeTransferFrom(address(tokenAddress), sender, address(this), amountToPay);
        emit Deposit(sender, amountToPay, amountToReceive, newAddress);
    }

     function deposit(
        uint256 amountToSend,
        address newAddress
    ) external
    {
        address sender = _msgSender();
        uint256 senderBalance = tokenAddress.balanceOf(sender);
        require(senderBalance >= amountToSend, "swapContract: Not enough balance");
        require(amountToSend >= minSwapAmountPerTx, "swapContract: Less than required minimum of tokens requested");
        require(amountToSend <= maxSwapAmountPerTx, "swapContract: Swap limit per transaction exceeded");
        require(swapLimitsSaved[sender], "swapContract: Swap limits not saved");

        (uint256[3] memory swapLimitsNew, uint256 amountToPay, uint256 amountToReceive) = calculateAmountsAfterSwap(
            swapLimits[sender], amountToSend, true
        );

        require(amountToPay > 0, "swapContract: Swap limit reached");
        require(amountToReceive > 0, "swapContract: Amount to receive is zero");

        swapLimits[sender] = swapLimitsNew;

        TransferHelper.safeTransferFrom(address(tokenAddress), sender, address(this), amountToPay);
        emit Deposit(sender, amountToPay, amountToReceive, newAddress);
    }

    function swapLimitsArray(address account) public view returns (uint256[3] memory)
    {
        return swapLimits[account];
    }

    function swapEnabledArray() public view returns (bool[3] memory)
    {
        return swapEnabled;
    }


    function calculateAmountsAfterSwap(
        uint256[3] memory _swapLimits,
        uint256 amountToSend,
        bool checkIfSwapEnabled
    ) public view returns (
        uint256[3] memory swapLimitsNew, uint256 amountToPay, uint256 amountToReceive)
    {
        amountToReceive = 0;
        uint256 remainder = amountToSend;
        for (uint256 i = 0; i < _swapLimits.length; i++) {
            if (checkIfSwapEnabled && !swapEnabled[i]) {
                continue;
            }
            uint256 swapLimit = _swapLimits[i];

            if (remainder <= swapLimit) {
                amountToReceive += remainder / swapRatios[i];
                _swapLimits[i] -= remainder;
                remainder = 0;
                break;
            } else {
                amountToReceive += swapLimit / swapRatios[i];
                remainder -= swapLimit;
                _swapLimits[i] = 0;
            }
        }
        amountToPay = amountToSend - remainder;
        swapLimitsNew = _swapLimits;
    }

    function claimTokens(address recipient, uint256 amount) external onlyOwner
    {
        uint256 balance = tokenAddress.balanceOf(address(this));
        require(balance >= amount, "swapContract: Not enough balance to claim");
        if (amount == 0) {
            amount = balance;
        }
        TransferHelper.safeTransfer(address(tokenAddress), recipient, amount);
        emit TokensClaimed(recipient, amount);
    }

    /**
      * @dev Function to check if address is belongs to owner role
      * @param account Address to check
      */
    function isOwner(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
      * @dev Function to check if address is belongs to validator role
      * @param account Address to check
      *
      */
    function isValidator(address account) public view returns (bool) {
        return hasRole(VALIDATOR_ROLE, account);
    }

    /**
      * @dev Changes requirement for minimal token amount on swaps
      * @param _minSwapAmountPerTx Amount of tokens
      */
    function setMinSwapAmountPerTx(uint256 _minSwapAmountPerTx) external onlyOwner {
        minSwapAmountPerTx = _minSwapAmountPerTx;
    }

    /**
      * @dev Changes requirement for maximum token amount on swaps
      * @param _maxSwapAmountPerTx Amount of tokens
      */
    function setMaxSwapAmountPerTx(uint256 _maxSwapAmountPerTx) external onlyOwner {
        maxSwapAmountPerTx = _maxSwapAmountPerTx;
    }
}