// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapLike {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Pair {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
    }

    mapping(bytes32 => Pair) public pairs;
    mapping(address => bool) public registeredTokens;

    event TokenRegistered(address indexed token);
    event PairCreated(address indexed token0, address indexed token1);
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, address indexed tokenIn, address indexed tokenOut);

    constructor() {}

    function registerToken(address token) external {
        require(!registeredTokens[token], "Token already registered");
        require(IERC20(token).totalSupply() > 0, "Invalid token");

        registeredTokens[token] = true;
        emit TokenRegistered(token);
    }

    function createPair(address tokenA, address tokenB) external {
        require(tokenA != tokenB, "UniswapLike: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "UniswapLike: ZERO_ADDRESS");
        require(registeredTokens[tokenA] && registeredTokens[tokenB], "Tokens not registered");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        require(pairs[pairHash].token0 == address(0), "UniswapLike: PAIR_EXISTS");

        pairs[pairHash] = Pair({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0
        });

        emit PairCreated(token0, token1);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        Pair storage pair = pairs[pairHash];
        require(pair.token0 != address(0), "UniswapLike: PAIR_DOES_NOT_EXIST");

        uint256 amount0 = tokenA < tokenB ? amountADesired : amountBDesired;
        uint256 amount1 = tokenA < tokenB ? amountBDesired : amountADesired;

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        pair.reserve0 = pair.reserve0.add(amount0);
        pair.reserve1 = pair.reserve1.add(amount1);
    }

    function swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external {
        require(amountIn > 0, "UniswapLike: INSUFFICIENT_INPUT_AMOUNT");
        require(tokenIn != tokenOut, "UniswapLike: IDENTICAL_ADDRESSES");

        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        Pair storage pair = pairs[pairHash];
        require(pair.token0 != address(0), "UniswapLike: PAIR_DOES_NOT_EXIST");

        bool isToken0 = tokenIn == pair.token0;
        (uint256 reserveIn, uint256 reserveOut) = isToken0 
            ? (pair.reserve0, pair.reserve1) 
            : (pair.reserve1, pair.reserve0);

        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut > 0, "UniswapLike: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        if (isToken0) {
            pair.reserve0 = reserveIn.add(amountIn);
            pair.reserve1 = reserveOut.sub(amountOut);
        } else {
            pair.reserve0 = reserveOut.sub(amountOut);
            pair.reserve1 = reserveIn.add(amountIn);
        }

        emit Swap(msg.sender, amountIn, amountOut, tokenIn, tokenOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapLike: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapLike: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
}