pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";
error InvalidAmount (uint256 sent, uint256 minRequired, uint256 unitsPurchased);

interface IMyNft {
    function balanceOf(address) external view returns (uint256);
    function tokenOfOwnerByIndex(address, uint256) external view returns (uint256);  
    function transferFrom(address, address,uint256) external ;
    function ownerOf(uint256) external view returns (address);
}

contract DEX is Ownable, ReentrancyGuard {
    /* ========== GLOBAL VARIABLES ========== */
    uint256 public totalLiquidity; //total amount of liquidity provider tokens (LPTs) minted (NOTE: that LPT "price" is tied to the ratio, and thus price of the assets within this AMM)
    mapping(address => uint256) public liquidity; //liquidity of each depositor
    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract
    address nftCollection;
    address public feesAddress = 0xe0f6DAcd86734Ea6fAa476565eD923Daac521064;
    // default value for fees is 1%
    uint256 public buyFee = 1010; // used to add fee when buying , 1010 = 1% fee, 1007 = .3% fee added to the buy price when buying
    uint256 public sellFee = 990; // value used to deduct selling fee 990 = 1% , 997 = 0.3%
    uint256 public baseFee = 1e17; // base fee on every transaction is .1 matic goes to Strawberri Dow NFT
    uint256 public k;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToNFT() swap transacted
     */
    event EthToTokenSwap(address swapper, string txDetails, uint256 ethInput, uint256 tokenOutput);

    event NFTBuy_EVENT(uint256 nftsPurchased, uint256 ethAmount); // emitted when nft/s is bought
    event NFTSell_EVENT(uint256 amount, uint256 salePrice);      // emitted when nft/s is sold
    /**
     * @notice Emitted when nftToEth() swap transacted
     */
    event TokenToEthSwap(address swapper, string txDetails, uint256 tokensInput, uint256 ethOutput);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address liquidityProvider, uint256 tokensInput, uint256 ethInput, uint256 liquidityMinted);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(
        address liquidityRemover,
        uint256 tokensOutput,
        uint256 ethOutput,
        uint256 liquidityWithdrawn
    );

    /* ========== CONSTRUCTOR ========== */

    constructor( address _collection)  {
        nftCollection = _collection;
     }

  // set the fee amount   1010 = 1% 1003 = .3%  1000 = 0%
     function setFee(uint256 _newFee ) public onlyOwner{
       require(_newFee < 21, "Can't set fee higher than 2%"); // 20 = 2% , 10 = 1% 3 = 0.3%
       buyFee = 1000 + _newFee;   
       sellFee = 1000 - _newFee; // value used to deduct selling fee 990 = 1% , 997 = 0.3%
     }

 // used for fee testing
 function setAddy(address adr) public {
     feesAddress = adr;
 }
     // returns how many NFTs are in the contract
     function getBalance() public view returns(uint256){
       return IMyNft(nftCollection).balanceOf(address(this)) ;   
     }

     function getID(uint256 _index, address _addr) public view returns(uint256){
       return IMyNft(nftCollection).tokenOfOwnerByIndex(_addr, _index) ;   
     }

      // add NFTs and ETH , this sets the x * y = k values
      // currently only the owner of this contract can initialise a collection
      // V2 will deliver a factory contract
    function initialiseLiquidity( uint256 _tokens) public payable onlyOwner{
        require(totalLiquidity == 0, "DEX: init - already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;  
  
        for(uint i=_tokens-1; i > 0 ; i --){
          IMyNft(nftCollection).transferFrom(msg.sender, address(this), getID(i, msg.sender ) );
        }
          IMyNft(nftCollection).transferFrom(msg.sender, address(this), getID(0, msg.sender ) ); // solidity cant handle negatives is why this is here
        k = totalLiquidity * _tokens;
    }

    /**
     * Gets the amount of eth the user will receive(fee deducted) when selling their NFTs to the AMM
     * xInput is amount of nfts being sold
     * xReserves is total NFTs, yReserves is Eth balance
     */
 function price(uint256 xInput,uint256 xReserves,uint256 yReserves) public view returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput.mul(sellFee);      // sellFee is 990 = 1% fee
        uint256 numerator = xInputWithFee.mul(yReserves); // 3988 * 1 eth
        uint256 denominator = (xReserves.mul(1000)).add(xInputWithFee);  // 20  * 1000 + 3988
        return (numerator / denominator) - baseFee ; // 3988 / 23988 = 0.1622
    }

 function priceNoFee(uint256 xInput,uint256 xReserves,uint256 yReserves) public pure returns (uint256 ) {
        uint256 numerator = xInput.mul(yReserves); // 3988 * 1 eth
        uint256 denominator = (xReserves).add(xInput);  // 20  * 1000 + 3988
        return (numerator / denominator); // 3988 / 23988 = 0.1622
    }

    function getETH(uint256 _tokens) public view returns (uint256) {
        return (k / getBalance()) - (k / (getBalance() + _tokens));   // 49
    }

    // fee charged when selling NFTs
    // 997 = 0.3%, 990 = 1%
    function changeSellFee(uint256 _amount) public onlyOwner  {
         sellFee = _amount;   
    }

   // fee charged when selling NFTs
    // 997 = 0.3%, 990 = 1%
    function changeBuyFee(uint256 _amount) public onlyOwner  {
         buyFee = _amount;   
    }

   // Send eth to user who is selling NFT less the fee the dex charges
    function getETHWithFee(uint256 _tokens) public view returns (uint256) {
        uint256 newY =  k / (getBalance() -  _tokens);
        uint256 eth_price  = (newY - address(this).balance) * sellFee / 1000 ; // sell fee (990) = less 1% fee
        return eth_price;
    }

    // user sells NFT to AMM and receives eth
    // requires user to do approve or approveAll if selling more than 1
    function sellNFT(uint256 _nftID) public nonReentrant returns (uint256 ) {
        require (IMyNft(nftCollection).ownerOf(_nftID)==msg.sender, "Not owner");  
        uint256 salePrice =  price(1, getBalance(), address(this).balance);
        IMyNft(nftCollection).transferFrom(msg.sender, address(this), _nftID); // transfer NFT     
        (bool sent, ) = payable(msg.sender).call{ value: salePrice }("");             // send eth
        require(sent, "nftToEth: revert in transferring eth to you!");     
        return salePrice;
    }

    // user sells NFT to AMM and receives eth
    // requires user to do approve or approveAll if selling more than 1
    function bulkSellNFT(uint256 _amount) public  nonReentrant returns (uint256 ) {
        require (IMyNft(nftCollection).balanceOf(msg.sender) >= _amount, "Not enough NFTs");  
        uint256 salePrice =  price(_amount, getBalance(), address(this).balance);
        uint256 fee = priceNoFee(_amount, getBalance(), address(this).balance) - salePrice;     
        if (_amount ==1){
          IMyNft(nftCollection).transferFrom(msg.sender, address(this), getID(0, msg.sender ) );
        }
        else{
         for(uint256 i = _amount; i > 0;) {
            IMyNft(nftCollection).transferFrom(msg.sender, address(this), getID(i, msg.sender ) );
            --i;
          }  
        }
 
        (bool sent, ) = payable(msg.sender).call{ value: salePrice }("");   // send eth to person who sold NFT
        require(sent, "nftToEth: revert in transferring eth to you!"); 
        (bool sent2, ) = payable(owner()).call{ value: fee }("");   // send fee to owners address
        require(sent2, "nftToEth: revert in sending fee");   
        (sent2, ) = payable(feesAddress).call{ value: baseFee }("");   // send fee to owners address
        require(sent2, "nftToEth: revert in sending fee");                
        emit NFTSell_EVENT(_amount, salePrice);
        return salePrice;
    }

     // users can buy NFTs using this function
    function buyNFT(uint256 amountToBuy) public nonReentrant payable  {
        uint256 eth_price  = getPrice(amountToBuy) ;// have to add msg.value
        uint256 fee = eth_price - getPriceNoFee(amountToBuy) - baseFee; // get fee
        require(msg.value == eth_price, "didn't send correct eth amount");
        require(amountToBuy <= getBalance());  // must be enough NFTs to purchase

       if (msg.value != eth_price) {  // require the correct amount of eth to be sent
            revert InvalidAmount({
                sent: msg.value,
                minRequired: eth_price, 
                unitsPurchased: address(this).balance
            });
        }
        for(uint256 i = 0; i < amountToBuy;) {
           IMyNft(nftCollection).transferFrom( address(this),msg.sender,getID(i, address(this)));
           unchecked {i++;}         // gas optimisation
        }
        (bool sent, ) = payable(owner()).call{ value: fee }("");   // send fee to owners address
        require(sent, "buyNFT: revert in sending fee");   
         (sent, ) = payable(feesAddress).call{ value: baseFee }("");   // send fee to owners address
        require(sent, "buyNFT: revert in sending base fee");          
        emit NFTBuy_EVENT(amountToBuy, msg.value);
    }

   // given the number of NFTs being purchased, returns the amount of eth required to purchase
    function getPrice(uint256 _nfts) public view returns(uint256){
        require (getBalance() - _nfts > 0, "Not enough NFT liquidity");
        uint256 currentY = k / getBalance();   // getBalance is number of NFTs
        uint256 NewX = getBalance() - _nfts;   // NFT balance less amount being purchased
        uint256 newY = k  / NewX ;               // 50 / 49= 1.1
        return (newY - currentY).mul(buyFee).div(1000) + baseFee; // base fee of .1 matic on every transaction
    }

   // given the number of NFTs being purchased, returns the amount of eth required to purchase
   // adds a .003% fee
    function getPriceNoFee(uint256 _nfts) public view returns(uint256){
        require (getBalance() - _nfts >=1, "Not enough NFT liqudidity");
        uint256 currentY = k / getBalance();
        uint256 x = getBalance() - _nfts;   // 49
        uint256 newY = k  / x ;               // 50 / 49= 1.1
        return (newY - currentY);                    // 1.02 / 49
    }

    /**
     * @notice returns liquidity for a user. Note this is notneeded typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     */
    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }


    /**
     * @notice v1 only allows owner to deposit and withdraw liquidity due to the complexity of the NFT AMM
     */
    function deposit(uint256 _tokens) public payable onlyOwner  nonReentrant returns (uint256) {
        require(_tokens >0, "Didnt specify token amount");
        require(msg.value > 0, "Didnt send eth");       
        require(totalLiquidity != 0, "DEX not initialised");
        uint256 oldLiquidity = address(this).balance - msg.value;
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;   

       for(uint i=_tokens-1; i > 0 ; i --){
          IMyNft(nftCollection).transferFrom(msg.sender, address(this), getID(i, msg.sender ) );
        }
          IMyNft(nftCollection).transferFrom(msg.sender, address(this), getID(0, msg.sender ) ); // solidity cant handle negatives is why this is here

        k = (address(this).balance)  * getBalance();
        emit LiquidityProvided(msg.sender, oldLiquidity, msg.value, _tokens);
        return oldLiquidity;
    }

    /**
     * @notice v1 only allows owner to add and remove liquidity
     * and they have to remove all liqudity
    */
    function withdraw(uint256 amount) public onlyOwner nonReentrant returns (uint256 eth_amount, uint256 token_amount) {
        require(liquidity[msg.sender] >= amount, "withdraw: sender does not have enough liquidity to withdraw.");
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = getBalance();  // get how many NFTs are in the contract


        liquidity[msg.sender] = liquidity[msg.sender].sub(amount);
        (bool sent, ) = payable(msg.sender).call{ value: ethReserve }("");
        require(sent, "withdraw(): revert in transferring eth to you!");
       // transfer NFTs to liquidity provider
         for(uint256 i = tokenReserve-1; i > 0;) {
            IMyNft(nftCollection).transferFrom( address(this), msg.sender, getID(i, address(this) ) );
            --i;
          }   
       IMyNft(nftCollection).transferFrom( address(this), msg.sender, getID(0, address(this) ) );
        emit LiquidityRemoved(msg.sender, amount, ethReserve, tokenReserve);
        return (ethReserve, tokenReserve);
    }
  
}
