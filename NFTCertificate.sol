//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTCertificate is ERC721URIStorage {

    using Counters for Counters.Counter;
    //_tokenIds variable has the most recent minted tokenId
    Counters.Counter private _tokenIds;
    //Keeps track of the number of items sold on the marketplace
    Counters.Counter private _itemsSold;
    //owner is the contract address that created the smart contract
    address payable owner;
    //The fee charged by the marketplace to be allowed to list an NFT
    uint256 listPrice = 0.01 ether;

    //The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable viewer;
        uint256 transferBackTime;
        bool currentlyListed;
        bool currentViewer; 
    
    }

    // The structure to store time information about a listed token 
    struct TokenTransferSchedule {
        uint256 transferBackTime;
        address transferBackTo;
    }

    //the event emitted when a token is successfully listed
    event TokenListedSuccess (
        uint256 indexed tokenId,
        address owner,
        address viewer,
        uint256 transferBackTime,
        bool currentlyListed,
        bool currentViewer
      
    );

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => ListedToken) private idToListedToken;

    // This mapping maps the tokenId to the token time infor and is helpful when retriving details about a tokenId
    mapping(uint256 => TokenTransferSchedule) private idToTransferSchedule;

    constructor() ERC721("NFTMarketplace", "NFTM") {
        owner = payable(msg.sender);
    }

    function updateListPrice(uint256 _listPrice) public payable {
        require(owner == msg.sender, "Only owner can update listing price");
        listPrice = _listPrice;
    }

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    function getLatestIdToListedToken() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }
     function getListedTokenTime(uint256 tokenId) public view returns (TokenTransferSchedule memory) {
        return idToTransferSchedule[tokenId];
    }
    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }
  

    //The first time a token is created, it is listed here
    function createToken(string memory tokenURI) public payable returns (uint) {
        //Increment the tokenId counter, which is keeping track of the number of minted NFTs
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        //Mint the NFT with tokenId newTokenId to the address who called createToken
        _safeMint(msg.sender, newTokenId);

        //Map the tokenId to the tokenURI (which is an IPFS URL with the NFT metadata)
        _setTokenURI(newTokenId, tokenURI);

        //Helper function to update Global variables and emit an event
        createListedToken(newTokenId);
        return newTokenId;
    }

    function createListedToken(uint256 tokenId) private {
        //Update the mapping of tokenId's to Token details, useful for retrieval functions
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(msg.sender),
            payable(msg.sender),
            0,
            true,
            false
        );

        //_transfer(msg.sender, address(this), tokenId);
        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(
            tokenId,
            msg.sender,
            msg.sender,
            0,
            true,
            false
        );
    }
    
    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint currentIndex = 0;
        uint currentId;
        //at the moment currentlyListed is true for all, if it becomes false in the future we will 
        //filter out currentlyListed == false over here
        for(uint i=0;i<nftCount;i++)
        {
            currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }
    
    //Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for(uint i=0; i < totalItemCount; i++)
        {
            // if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender){
            //     itemCount += 1;
            // }
            if(idToListedToken[i+1].viewer == msg.sender){
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for(uint i=0; i < totalItemCount; i++) {
            // if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender) {
            //     currentId = i+1;
            //     ListedToken storage currentItem = idToListedToken[currentId];
            //     items[currentIndex] = currentItem;
            //     currentIndex += 1;
            // }
            if(idToListedToken[i+1].viewer == msg.sender) {
                currentId = i+1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function executeTransfer(uint256 tokenId, address receiver, uint256 transferBackTime) public {
    require(idToListedToken[tokenId].owner == msg.sender, "Only token owner can transfer Viewer rights ");
    // lets converet the time into seconds for now.
    transferBackTime = transferBackTime+block.timestamp ;
    //update the details of the token
    idToListedToken[tokenId].currentlyListed = false;
    idToListedToken[tokenId].currentViewer = true;
    idToListedToken[tokenId].viewer = payable(receiver);
    //idToListedToken[tokenId].owner = payable(receiver);
    idToListedToken[tokenId].transferBackTime = transferBackTime;
    _itemsSold.increment();

    if (transferBackTime > 0) {
        TokenTransferSchedule storage schedule = idToTransferSchedule[tokenId];
        schedule.transferBackTime = transferBackTime;
        schedule.transferBackTo = idToListedToken[tokenId].owner;

    }}


    function transferOwnership(uint256 tokenId) public  {
    require(idToListedToken[tokenId].owner == msg.sender, "Only token owner can transfer ownership back");
    require(idToListedToken[tokenId].currentViewer == false, "You are not the owner just the viewwer ");
    
     TokenTransferSchedule storage scheduledTransfer = idToTransferSchedule[tokenId];
     if (scheduledTransfer.transferBackTime > 0 && block.timestamp >= scheduledTransfer.transferBackTime) {
        //address viewer = scheduledTransfer.transferBackTo;
        //_transfer(receiver, seller, tokenId);
        idToListedToken[tokenId].currentlyListed = true;
        idToListedToken[tokenId].viewer = payable(msg.sender);
        
    }
    
    }



 }
