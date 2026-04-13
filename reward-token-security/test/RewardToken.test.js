const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RewardToken Security Tests", function () {

 let token;
 let owner;
 let player1;
 let player2;

 beforeEach(async function () {

   [owner, player1, player2] = await ethers.getSigners();

   const RewardToken = await ethers.getContractFactory("RewardToken");

   token = await RewardToken.deploy();

   await token.waitForDeployment();

 });

 it("valid winner can claim reward", async function () {

   const battleId = ethers.id("battle1");

   await token.setBattleWinner(battleId, player1.address);

   await token.connect(player1).claimReward(
        battleId,
        ethers.parseEther("10")
   );

   expect(
        await token.isRewardClaimed(battleId)
   ).to.equal(player1.address);

 });

 it("non winner cannot claim", async function () {

   const battleId = ethers.id("battle2");

   await token.setBattleWinner(battleId, player1.address);

   await expect(

        token.connect(player2).claimReward(
            battleId,
            ethers.parseEther("10")
        )

   ).to.be.reverted;

 });

 it("cannot claim twice", async function () {

   const battleId = ethers.id("battle3");

   await token.setBattleWinner(battleId, player1.address);

   await token.connect(player1).claimReward(
        battleId,
        ethers.parseEther("10")
   );

   await expect(

        token.connect(player1).claimReward(
            battleId,
            ethers.parseEther("10")
        )

   ).to.be.reverted;

 });

 it("cannot exceed max reward per battle", async function () {

   const battleId = ethers.id("battle4");

   await token.setBattleWinner(battleId, player1.address);

   await expect(

        token.connect(player1).claimReward(
            battleId,
            ethers.parseEther("2000")
        )

   ).to.be.reverted;

 });

 it("cannot exceed total reward pool", async function () {

   const battleId = ethers.id("battle5");

   await token.setBattleWinner(battleId, player1.address);

   await token.connect(player1).claimReward(
        battleId,
        ethers.parseEther("1000")
   );

   const battleId2 = ethers.id("battle6");

   await token.setBattleWinner(battleId2, player1.address);

   await expect(

        token.connect(player1).claimReward(
            battleId2,
            ethers.parseEther("600000")
        )

   ).to.be.reverted;

 });

});