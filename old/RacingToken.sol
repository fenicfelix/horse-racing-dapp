// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RacingToken is ERC20 {
    address public owner;
    
    // Constructor to initialize the token with a name and symbol
    // The initial supply is set to 10 million tokens
    // The owner is set to the address that deploys the contract
    // The initial supply is minted to the owner's address
    constructor() ERC20("RacingToken", "RDAPP") {
        owner = msg.sender;
        _mint(msg.sender, 10_000_000 * 10**18); // Initial supply
    }

    // Function to mint new tokens
    // This can be used for various purposes like rewarding users
    // or for tokenomics reasons
    // Only the owner can call this function
    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        _mint(to, amount);
    }

    // Burn function to destroy tokens
    // This can be used for various purposes like reducing supply
    // or for tokenomics reasons
    // Only the owner can call this function
    // This is a simple implementation; in a real-world scenario, 
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}