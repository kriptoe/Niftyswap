// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNft is ERC721, ERC721Enumerable, Ownable {
  using Strings for uint256;

  uint256 public supply = 0;
  uint16 immutable i_maxSupply = 500;
  string private s_baseURI="ipfs://bafybeidmpeugtspdshfqojj22snvb6tbvjgyqmnblmqi45jol42oyeokpu/";
  string public baseExtension = ".json";

    constructor() ERC721("Lisurgik Strawberri Dow", "lsd") {
       mintBulk(100);
    }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return s_baseURI;
  }

    function mintBulk(uint256 _amount) public onlyOwner {
      require(i_maxSupply >= _amount + supply, "max supply exceeded");
      uint256 counter = supply;

        for(uint256 i = 0; i < _amount;) {
            unchecked {++i;}                   // want the increment here otherwise first ID would be 0
            _safeMint(msg.sender, counter + i); 
        }
         supply = supply + _amount; //cant bulk increase counter
    }

    // The following functions are overrides required by Solidity.

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    s_baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  function tokenURI(uint256 tokenId) public view virtual override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

