// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title reBTC - Remapped Bitcoin Token
/// @notice This ERC20 token represents Bitcoin delegated via Vault
contract reBTC is ERC20, Ownable {
    constructor() ERC20("Remapped Bitcoin", "reBTC") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
