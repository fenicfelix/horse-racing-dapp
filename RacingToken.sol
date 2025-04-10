// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RacingDAppToken is ERC20 {
    address public owner;
    
    constructor() ERC20("RacingDAppToken", "RDAPP") {
        owner = msg.sender;
        _mint(msg.sender, 10_000_000 * 10**18); // Initial supply
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}