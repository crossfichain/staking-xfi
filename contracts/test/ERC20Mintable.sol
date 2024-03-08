// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

contract ERC20Mintable is ERC20, Ownable {
	constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

	function mint(address receiver, uint256 amount) public onlyOwner {
		_mint(receiver, amount);
	}
}
