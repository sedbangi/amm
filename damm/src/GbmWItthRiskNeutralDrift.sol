// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./MathLibrary.sol";

contract GeometricBrownianMotion {
    using MathLibrary for uint256;

    uint256 public S0;
    uint256 public mu;
    uint256 public sigma;
    uint256 public T;
    uint256 public n;
    uint256[] public prices;

    constructor(uint256 _S0, uint256 _mu, uint256 _sigma, uint256 _T, uint256 _n) {
        S0 = _S0;
        mu = _mu;
        sigma = _sigma;
        T = _T;
        n = _n;
        prices = new uint256[](_n + 1);
        prices[0] = _S0;
    }

    function generateGBM() public {
        uint256 dt = T / n;
        uint256 drift = mu - (sigma ** 2) / 2;
        for (uint256 i = 1; i <= n; i++) {
            uint256 randomShock = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i))) % 100;
            uint256 diffusion = sigma * randomShock;
            prices[i] = prices[i - 1] * (1 + drift * dt + diffusion * dt.sqrt());
        }
    }

    function getPrices() public view returns (uint256[] memory) {
        return prices;
    }
}