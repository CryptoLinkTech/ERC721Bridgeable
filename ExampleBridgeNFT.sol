// SPDX-License-Identifier: MIT
// Author: Atlas (atlas@cryptolink.tech)

pragma solidity ^0.8.9;

import "./ERC721Bridgeable.sol";

/**
 * @notice Example natively bridgeable NFT for use over TBaaS.
 * @author Atlas (atlas@cryptolink.tech)
 * 
 * When deploying, make sure to use a unique, non-overlapping ID_START+MAX_SUPPLY between chains. NFT
 * IDs must be unique across chains. (idStart = chainId * 100_000)
 * 
 * All bridging functionality is handled inside the extension. This parent contract only needs to be 
 * concerned about the NFT itself and the minting to purchasers.
 * 
 * Deploying with 3 steps:
 *   - Modify and launch this contract on all desired chains, taking into account the _idStart constructor
 *   - Connect your wallet on https://tbaas.io dApp and enable this contract on every desired chain
 *   - Make sure contract has enough WETH for fees, or charges enough in WETH to bridgers
 * 
 */
contract ExampleBridgeNFT is ERC721Bridgeable {
    uint public ID_START;
    uint public MAX_SUPPLY;
    uint public AMOUNT_MINTED;

    /**
     * @param _tbaas Address of the TBaaS Bridge
     * @param _idStart ID of the NFT start address (ids must be unique between all of the chains)
     * @param _maxSupply Maximum numbers of NFTs to mint
     */
    constructor(address _tbaas, uint _idStart, uint _maxSupply) ERC721Bridgeable("Examble ERC721 Bridgeable NFT", "bNFT", _tbaas) {
    }

    /**
     * @dev add payments, tokenomics, whitelists, etc here
     */
    function mint() public {
        require(AMOUNT_MINTED < MAX_SUPPLY, "ExampleBridgeNFT: nfts are minted out!");
        
        // todo: take fees, whitelist checks, etc

        // set tokenURI to data, url, ipfs, etc .. everything inside preserves across chains
        string memory _tokenURI = "";
        _mint(msg.sender, ID_START+AMOUNT_MINTED);
        _setTokenURI(ID_START+AMOUNT_MINTED, _tokenURI);
        
        AMOUNT_MINTED++;
    }
}