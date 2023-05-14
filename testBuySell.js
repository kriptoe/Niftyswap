const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Niftyswap AMM Testing : buy and sell', function () {
    
    let deployer, user1, user2, user3;
    const ONE_ETHER = ethers.utils.parseEther('1'); 
 

    before(async function () {
        /** Deployment and minting tests */
        [deployer, user1, user2, user3] = await ethers.getSigners();
    });

    it('TEST 1: Deploy NFT and Dex Contracts and mint 600 NFTs (constructor mints 100)', async function () {
      const DEPOSIT_AMOUNT = 600  
      const tokenFactory = await ethers.getContractFactory('contracts/MyNft.sol:MyNft', deployer);
      this.nft = await tokenFactory.deploy();   
      const dexFactory = await ethers.getContractFactory('DEX', deployer);
      this.dexPlace = await dexFactory.deploy(this.nft.address);  
      await this.nft.mintBulk(200);
      await this.nft.mintBulk(200); 
      await this.nft.mintBulk(100);           
      console.log("Contract's NFT balance ", await this.nft.balanceOf(deployer.address));
      expect (await this.nft.balanceOf(deployer.address)).to.be.equal(DEPOSIT_AMOUNT);  
    });
    

    it('TEST 2 : Initialise liquidity with 200 nfts with 200 eth(matic) then add liquidity of 400 nfts with 4 eth', async function () {
     await this.nft.setApprovalForAll(this.dexPlace.address, true);  // give approval
     await this.dexPlace.initialiseLiquidity( 200, {value:ethers.utils.parseEther("200")});    
     console.log("k after initialisation = ", await this.dexPlace.k())
      x = await this.nft.balanceOf(deployer.address)
     await this.dexPlace.deposit( 200, {value:ethers.utils.parseEther("200")});  
     await this.dexPlace.deposit( 200, {value:ethers.utils.parseEther("200")});       
     expect (await this.nft.balanceOf(this.dexPlace.address)).to.be.equal(600); 
     expect (await ethers.provider.getBalance(this.dexPlace.address)).to.be.equal(ethers.utils.parseEther("600"));
    });

    it('TEST 3 : Buy and sell NFTs from different accounts', async function () {
      await this.nft.connect(user1).setApprovalForAll(this.dexPlace.address, true);  // give approval
      await this.nft.connect(user2).setApprovalForAll(this.dexPlace.address, true);  // give approval
      await this.nft.connect(user3).setApprovalForAll(this.dexPlace.address, true);  // give approval   
      console.log("Deployer/owner  balance */",await ethers.provider.getBalance(deployer.address))

      console.log("cost of buying 7 NFTs", ethers.utils.formatEther(await this.dexPlace.getPrice(7)))
       // USER 1 buy 7 NFTs then sell 4
       await this.dexPlace.connect(user1).buyNFT( 7 ,{value:await this.dexPlace.getPrice(7)}) 
       await this.dexPlace.connect(user1).bulkSellNFT(4)
       expect (await this.nft.balanceOf(user1.address)).to.be.equal(3); 

       // USER 2 buy 8 NFTs then sell 2     
       // await this.dexPlace.connect(user2).buyNFT( 8 ,{value:await this.dexPlace.getPrice(8)}) 
       await this.dexPlace.connect(user2).buyNFT( 8 ,{value:await this.dexPlace.getPrice(8)})
       await this.dexPlace.connect(user2).bulkSellNFT(7)     
       await this.dexPlace.connect(user2).bulkSellNFT(1)       
       expect (await this.nft.balanceOf(user2.address)).to.be.equal(0); 

        // USER 3 buy 8 NFTs then sell 2     
       // await this.dexPlace.connect(user2).buyNFT( 8 ,{value:await this.dexPlace.getPrice(8)}) 
       await this.dexPlace.connect(user3).buyNFT( 10 ,{value:await this.dexPlace.getPrice(10)})   
       expect (await this.nft.balanceOf(user3.address)).to.be.equal(10); 
       expect (await this.nft.balanceOf(this.dexPlace.address)).to.be.equal(587);   
       

       console.log("dex nft bal ", await this.nft.balanceOf(this.dexPlace.address))
       // for (let i=0; i < 60; i++)
      //  console.log("nft id ", i , " is " , await this.nft.tokenOfOwnerByIndex(this.dexPlace.address, i)   )
         await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
         console.log("buying 20 NFTS --------------------------") 
         await this.dexPlace.connect(user3).buyNFT( 20 ,{value:await this.dexPlace.getPrice(20)})  
         console.log("buying 10 NFTS --------------------------") 
         await this.dexPlace.connect(user3).buyNFT( 10 ,{value:await this.dexPlace.getPrice(10)}) 
         console.log("buying 6 NFTS --------------------------") 
         await this.dexPlace.connect(user3).buyNFT( 6 ,{value:await this.dexPlace.getPrice(6)})                        
         await this.dexPlace.connect(user3).bulkSellNFT(5)  
         for (let i=0; i<40;i++){
          await this.dexPlace.connect(user3).buyNFT( 5 ,{value:await this.dexPlace.getPrice(5)})  
          await this.dexPlace.connect(user3).bulkSellNFT(5)  
         } 
     
     //  for (let i=0; i < 50; i++)
    //     console.log("nft id ", i , " is " , await this.nft.tokenOfOwnerByIndex(i)   )
       console.log("Deployer/owner  balance after sales fees */",await ethers.provider.getBalance(deployer.address))  
       console.log("Contract balance ",await ethers.provider.getBalance(this.dexPlace.address))          
    });

    it('TEST 5 : Check fees are sent to fee deployer address', async function () {
      console.log("Fee address balance ",await ethers.provider.getBalance(deployer.address))    
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)})  
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)}) 
      await this.dexPlace.connect(user3).buyNFT( 40 ,{value:await this.dexPlace.getPrice(40)})         
      console.log("Fee address balance ",await ethers.provider.getBalance(deployer.address))  
    });


    it('TEST 6 : Remove liquidity', async function () {
        await this.dexPlace.connect(deployer).withdraw(await this.dexPlace.getLiquidity( deployer.address)) ;    

        console.log("NFT balance  ", await this.nft.balanceOf(this.dexPlace.address) ) 
        console.log("ETH balance  ", await ethers.provider.getBalance(this.dexPlace.address) )        
        expect (await this.nft.balanceOf(this.dexPlace.address)).to.be.equal(0); 
        expect (await ethers.provider.getBalance(this.dexPlace.address)).to.be.equal(0);
      });

});
