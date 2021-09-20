// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";


contract SwapContract is AccessControlEnumerable
{
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    IERC20 public tokenAddress;
    uint256 public maxSwapAmountPerTx;
    uint256 public minSwapAmountPerTx;

    uint128 [3] public swapRatios;
    bool [3] public swapEnabled;

    mapping(address => bool) public swapLimitsSaved;
    mapping(address => uint256 [3]) swapLimits;

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
      * @param _tokenAddress Token contract address
      * @param validatorAddress Swap limits validator address
      * @param _swapRatios Swap ratios array
      * @param _swapEnabled Array that represents if swap enabled for ratio
      * @param _minSwapAmountPerTx Minimum token amount for swap per transaction
      * @param _maxSwapAmountPerTx Maximum token amount for swap per transaction
      */
    constructor(
        IERC20 _tokenAddress,
        address validatorAddress,
        uint128 [3] memory _swapRatios,
        bool [3] memory _swapEnabled,
        uint256 _minSwapAmountPerTx,
        uint256 _maxSwapAmountPerTx
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

     /**
      * @dev Transfers tokens from sender to the contract.
      * User calls this function when he wants to deposit tokens for the first time.
      * @param amountToSend Maximum amount of tokens to send
      * @param newAddress Address in the blockchain where the user wants to get tokens
      * @param signedAddress Signed Address
      * @param signedSwapLimits Signed swap limits
      * @param signature Signed address + swapLimits keccak hash
      */
    function depositWithSignature(
        uint256 amountToSend,
        address newAddress,
        address signedAddress,
        uint256 [3] memory signedSwapLimits,
        bytes memory signature
    ) external
    {
        address sender = _msgSender();
        uint256 senderBalance = tokenAddress.balanceOf(sender);
        require(senderBalance >= amountToSend, "swapContract: Insufficient balance");
        require(amountToSend >= minSwapAmountPerTx, "swapContract: Less than required minimum of tokens requested");
        require(amountToSend <= maxSwapAmountPerTx, "swapContract: Swap limit per transaction exceeded");
        require(sender == signedAddress, "swapContract: Signed and sender address does not match");
        require(!swapLimitsSaved[sender], "swapContract: Swap limits already saved");

        bytes32 hashedParams = keccak256(abi.encodePacked(signedAddress, signedSwapLimits));
        address validatorAddress = ECDSA.recover(ECDSA.toEthSignedMessageHash(hashedParams), signature);
        require(isValidator(validatorAddress), "swapContract: Invalid swap limits validator");

        (uint256[3] memory swapLimitsNew, uint256 amountToPay, uint256 amountToReceive) = calculateAmountsAfterSwap(
            signedSwapLimits, amountToSend, true
        );
        require(amountToPay > 0, "swapContract: Swap limit reached");
        require(amountToReceive > 0, "swapContract: Amount to receive is zero");

        swapLimits[signedAddress] = swapLimitsNew;
        swapLimitsSaved[sender] = true;

        TransferHelper.safeTransferFrom(address(tokenAddress), sender, address(this), amountToPay);
        emit Deposit(sender, amountToPay, amountToReceive, newAddress);
    }

    /**
      * @dev Transfers tokens from sender to the contract.
      * User calls this function when he wants to deposit tokens
      * if the swap limits have been already saved into the contract storage
      * @param amountToSend Maximum amount of tokens to send
      * @param newAddress Address in the blockchain where the user wants to get tokens
      */
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

    /**
      * @dev Calculates actual amount to pay, amount to receive and new swap limits after swap
      * @param _swapLimits Swap limits array
      * @param amountToSend Maximum amount of tokens to send
      * @param checkIfSwapEnabled Check if swap enabled for a ratio
      * @return swapLimitsNew Swap limits after deposit is processed
      * @return amountToPay Actual amount of tokens to pay (amountToPay <= amountToSend)
      * @return amountToReceive Amount of tokens to receive after deposit is processed
      */
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
            if (checkIfSwapEnabled && !swapEnabled[i] || swapRatios[i] == 0) {
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

    /**
      * @dev Claims the deposited tokens
      * @param recipient Tokens recipient
      * @param amount Tokens amount
      */
    function claimTokens(address recipient, uint256 amount) external onlyOwner
    {
        uint256 balance = tokenAddress.balanceOf(address(this));
        require(balance > 0, "swapContract: Token balance is zero");
        require(balance >= amount, "swapContract: Not enough balance to claim");
        if (amount == 0) {
            amount = balance;
        }
        TransferHelper.safeTransfer(address(tokenAddress), recipient, amount);
        emit TokensClaimed(recipient, amount);
    }

    /**
      * @dev Changes requirement for minimal token amount to deposit
      * @param _minSwapAmountPerTx Amount of tokens
      */
    function setMinSwapAmountPerTx(uint256 _minSwapAmountPerTx) external onlyOwner {
        minSwapAmountPerTx = _minSwapAmountPerTx;
    }

    /**
      * @dev Changes requirement for maximum token amount to deposit
      * @param _maxSwapAmountPerTx Amount of tokens
      */
    function setMaxSwapAmountPerTx(uint256 _maxSwapAmountPerTx) external onlyOwner {
        maxSwapAmountPerTx = _maxSwapAmountPerTx;
    }

    /**
      * @dev Changes swap ratio
      * @param index Ratio index
      * @param ratio Ratio value
      */
    function setSwapRatio(uint128 index, uint128 ratio) external onlyOwner {
        swapRatios[index] = ratio;
    }

    /**
      * @dev Enables swap for a ratio
      * @param index Swap rate index
      */
    function enableSwap(uint128 index) external onlyOwner {
        swapEnabled[index] = true;
    }

    /**
      * @dev Disables swap for a ratio
      * @param index Swap rate index
      */
    function disableSwap(uint128 index) external onlyOwner {
        swapEnabled[index] = false;
    }

    /**
      * @dev Function to check if address is belongs to owner role
      * @param account Account address to check
      */
    function isOwner(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
      * @dev Function to check if address is belongs to validator role
      * @param account Account address to check
      */
    function isValidator(address account) public view returns (bool) {
        return hasRole(VALIDATOR_ROLE, account);
    }

    /**
      * @dev Returns account swap limits array
      * @param account Account address
      * @return Account swap limits array
      */
    function swapLimitsArray(address account) external view returns (uint256[3] memory)
    {
        return swapLimits[account];
    }

    /**
      * @dev Returns array that represents if swap enabled for ratio
      * @return Array that represents if swap enabled for ratio
      */
    function swapEnabledArray() external view returns (bool[3] memory)
    {
        return swapEnabled;
    }
}