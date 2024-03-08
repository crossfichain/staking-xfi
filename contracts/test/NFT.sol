import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract NFT is ERC721 {
	uint256 public totalSupply;
	string internal baseURI;

	constructor(string memory baseURI_, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
		for (uint i = 0; i < 10; i++) {
			_mint(msg.sender, i);
			totalSupply = 10;
		}

		baseURI = baseURI_;
	}

	function _baseURI() internal view virtual override returns (string memory) {
		return baseURI;
	}

	function mint() public {
		_mint(msg.sender, totalSupply);
		totalSupply += 1;
	}
}
