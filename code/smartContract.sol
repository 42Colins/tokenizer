// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importing ERC20 library
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/BEP20/IBEP20.sol";

// Creating an error function for not being the owner of the contract
error ErrorOwnerOnlyFunction();

contract FourtyTwotoTheMoon is ERC20, ERC20Permit {
    address public owner;
    uint256 private constant INITIAL_SUPPLY = 42_000_000 * 10**18;

    modifier onlyOwner() {      // Modifier to check if the user is the creator of the contract
        if (msg.sender != owner)
            revert ErrorOwnerOnlyFunction();
        _;
    }

    constructor() ERC20("42toTheMoon", "42Moon") ERC20Permit("42toTheMoon") { // Constructor for our BEP20 token named 42toTheMoon
        owner = msg.sender;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address dest, uint256 amount) public onlyOwner { // Function calling the BEP20 function _mint to produce the tokens
        _mint(dest, amount);
    }

    function burn(uint256 amount) public { // Function calling the BEP20 function _burn used to burn tokens (reducing the total supply therefore making the token more rare)
        _burn(msg.sender, amount);
    }

    // Transfering the token directly from an address to another
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(recipient, amount);
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    // Transfering the token 
}
