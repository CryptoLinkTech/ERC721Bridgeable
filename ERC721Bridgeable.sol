// Author: Atlas (atlas@cryptolink.tech)

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITBaaS {
    function sourceChainRequestTokenBridge(uint toChainId, address recipient, uint amount) external returns(uint txId);
    function sourceChainRequestNFTBridge(uint toChainId, address recipient, uint nftId, string calldata tokenURI) external returns(uint txId);
    function isDestinationChainEnabledForProject(address project, uint chainId) external view returns (bool enabled);
    function getPaymentToken(address project) external view returns(address paymentToken);
    function getRequestFee(uint destChainId, address project) external view returns (uint feeAmount);
    function pay(uint paymentamount) external returns (bool paid);
    function getCurrentAddress() external view returns(address tbaas);
}

/**
 * @title Base class for creating natively bridgeable ERC721 NFT
 * @author Atlas (atlas@cryptolink.tech)
 * 
 * Overview:
 *   This extention enables developers to create a cross chain native bridgeable ERC721 NFT. All
 *   required functionality is included in this extension, and does not require any additional code
 *   on the parent contract. Developers are free to design their NFT as they wish. 
 * 
 * Security:
 *   This extension provides two new functions, bridgeRequest() and bridgeProcess().
 * 
 *   bridgeRequest() is public, anyone can have their NFT burned in exchange for a valid
 *   bridge request event. The bridge handels delivery on the desination chain by calling 
 *   the bridgeProcess() function on the destination chain contract.
 *   
 *   bridgeProcess() is restricted to calls only from the Bridge. We can rely on only valid messages
 *   reaching this function. All calls coming from the bridge have ran through all the layers of
 *   security and have been found to pass. The security of this message is auditable by viewing the
 *   corresponding function in the bridge code.
 * 
 *   TBAAS Address is updated automatically by the Bridge for upgrades. TBAAS is only able to upgrade
 *   the address when deploying revisions and only during a secure timeout-period and events are sent
 *   to prevent mallicious actions to allow inspection of the change before becoming active.
 * 
 */
contract ERC721Bridgeable is ERC721Burnable {
    address private TBAAS;

    mapping (uint256 => string) public TOKEN_URIS;

    event BridgeProcess(uint txId, uint sourceChainId, address recipient, uint tokenAmount, uint gasAmount);
    event BridgeRequest(uint toChainId, address recipient, uint amount);

    /**
     * @param _name Name of the NFT Collection
     * @param _symbol Symbol of the NFT Collection
     * @param _tbaas Address of the TBaaS contract
     */
    constructor(string memory _name, string memory _symbol, address _tbaas) ERC721(_name, _symbol) {
        TBAAS = _tbaas;
    }

    /**
     * @param _toChainId ID of the destination chain
     * @param _recipient Address of the recipient
     * @param _nftId ID of the NFT
     * @dev Parent contract should make sure available WETH exists in contract to pay bridge fee.
     * @dev You may program the contract to take the fees from the user bridging the NFT.
     */
    function bridgeRequest(uint _toChainId, address _recipient, uint _nftId) external {
        require(ITBaaS(TBAAS).isDestinationChainEnabledForProject(address(this), _toChainId) == true, "ERC721Bridgeable: destination chain not enabled for project");

        // handle TBaaS upgrades
        if(ITBaaS(TBAAS).getCurrentAddress() != address(TBAAS)) TBAAS = ITBaaS(TBAAS).getCurrentAddress();

        // save the metadata and burn the NFT from this chain
        string memory _tokenURI = tokenURI(_nftId);
        _burn(_nftId);

        // notify the bridge that the NFT has been burned which runs bridgeProcess() in this contract on the destination chain
        IERC20(ITBaaS(TBAAS).getPaymentToken(address(this))).approve(address(TBAAS), ITBaaS(TBAAS).getRequestFee(_toChainId, address(this)));
        ITBaaS(TBAAS).sourceChainRequestNFTBridge(_toChainId, _recipient, _nftId, _tokenURI);

        emit BridgeRequest(_toChainId, _recipient, _nftId);
    }

    /**
     * @param _txId Bridge transaction ID
     * @param _sourceChainId ID of the source chain of this request
     * @param _recipient Recipient of the NFT
     * @param _nftId ID of the NFT to send to the recipient
     * @param _paymentRequired Payment required to be sent to the bridge in WETH
     * @dev This must only be ran by TBAAS as the checks are all done upstream.
     * @dev Parent contract should make sure available WETH exists in contract to pay bridge fee.
     * @dev You may program the contract to take the fees from the user bridging the NFT.
     */
    function bridgeProcess(uint _txId, uint _sourceChainId, address _recipient, uint _nftId, string calldata _tokenURI, uint _paymentRequired) internal {
        // we can be sure the message has been validated correctly on all layers when delivered directly from TBAAS
        require(msg.sender == address(TBAAS), "ERC721Bridgeable: not authorized");

        // mint NFT to the recipient
        _mint(_recipient, _nftId);
        _setTokenURI(_nftId, _tokenURI);

        if(_paymentRequired > 0) {
            // if the required minimum payment is not sent, the entire transaction will be reverted
            IERC20(ITBaaS(TBAAS).getPaymentToken(address(this))).approve(address(TBAAS), _paymentRequired);
            ITBaaS(TBAAS).pay(_paymentRequired);
        }

        emit BridgeProcess(_txId, _sourceChainId, _recipient, _nftId, _paymentRequired);
    }

    /**
     * @param _tokenId NFT ID to retrieve metadata
     */
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Bridgeable: nonexistent token");
        return TOKEN_URIS[_tokenId];
    }    

    /**
     * @param _tokenId NFT ID to set metadata
     * @param _tokenURI Metadata of the NFT
     */
    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal virtual {
        require(_exists(_tokenId), "ERC721Bridgeable: nonexistent token");
        TOKEN_URIS[_tokenId] = _tokenURI;
    }
}