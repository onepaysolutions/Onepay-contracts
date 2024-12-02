// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTBase.sol";

contract AngelNFT is NFTBase {
    constructor(
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _usdcToken,
        address _opeToken
    ) NFTBase(
        "Angel NFT",
        "ANGEL",
        _royaltyRecipient,
        _royaltyBps,
        _usdcToken,
        _opeToken,
        1000e6,    // 1000 USDT claim price
        1000e18,   // 1000 OPE mining reward
        1000e18,   // 1000 OPE referral reward
        300        // 300 max supply
    ) {}
}