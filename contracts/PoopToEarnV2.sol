// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PoopToEarnV2 is Ownable {

    address private tokenAddr = 0x3AA14Ed2d1A65a58DF0237fA84239F97fF4E9B42; // BLOBz
    address private nftAddr = 0x8E56343adAFA62DaC9C9A8ac8c742851B0fb8b03; // Bored Town
    uint public claimAmount = 888 * (10**18);
    uint public bonusAmount = 888 * (10**18);
    uint public cooldown = 60; // seconds
    uint public sCooldown = 10; // seconds
    uint public aCooldown = 20; // seconds
    uint public bCooldown = 30; // seconds
    uint public cCooldown = 40; // seconds
    bool public claimActive = true;

    IERC20 public token;
    IERC721 public nft;
    IERC721 public sNFT;
    IERC721 public aNFT;
    IERC721 public bNFT;
    IERC721 public cNFT;
    mapping(address => uint) public lastTimeStamps;

    constructor(address initialOwner) Ownable(initialOwner) {
        token = IERC20(tokenAddr);
        nft = IERC721(nftAddr);
        sNFT = IERC721(0x32f1B16434e919953B728e18594AAb38B816d97e); // Space BLOBz Tier S
        aNFT = IERC721(0xd2779A62a941217173D987dAaE130dA470cBE49e); // Space BLOBz Tier A
        bNFT = IERC721(0x976bf7A9bf341f10218a9E721df117774E433668); // Space BLOBz Tier B
        cNFT = IERC721(0x3474a068b163265B19d4cab192dD40B75f8092eE); // Space BLOBz Tier C
    }

    // manage contract (owner)
    function setToken(address _addr) external onlyOwner { token = IERC20(_addr); }
    function setNFT(address _addr) external onlyOwner { nft = IERC721(_addr); }
    function setClaimAmount(uint _amount) external onlyOwner { claimAmount = _amount; }
    function setBonusAmount(uint _amount) external onlyOwner { bonusAmount = _amount; }
    function setCooldown(uint _cooldown) external onlyOwner { cooldown = _cooldown; }
    function setCooldownS(uint _cooldown) external onlyOwner { sCooldown = _cooldown; }
    function setCooldownA(uint _cooldown) external onlyOwner { aCooldown = _cooldown; }
    function setCooldownB(uint _cooldown) external onlyOwner { bCooldown = _cooldown; }
    function setCooldownC(uint _cooldown) external onlyOwner { cCooldown = _cooldown; }
    function toggleClaim() external onlyOwner { claimActive = !claimActive; }
    function withdraw() external onlyOwner {
        uint balance = token.balanceOf(address(this));
        require(balance > 0, "No token to withdraw.");
        require(token.transfer(msg.sender, balance), "Token transfer failed.");
    }

    // claim token
    function calcClaimAmount(address addr) public view returns (uint) {
        if (nft.balanceOf(addr) > 0) // holder
            return claimAmount + bonusAmount;
        else // non-holder
            return claimAmount;
    }
    function calcCooldown(address addr) public view returns (uint) {
        if (sNFT.balanceOf(addr) > 0)
            return sCooldown;
        else if (aNFT.balanceOf(addr) > 0)
            return aCooldown;
        else if (bNFT.balanceOf(addr) > 0)
            return bCooldown;
        else if (cNFT.balanceOf(addr) > 0)
            return cCooldown;
        else
            return cooldown;
    }
    function claim() external {
        // check active
        require(claimActive, "Claim is not activated.");

        // check token balance
        uint calcAmount = calcClaimAmount(msg.sender);
        require(calcAmount <= token.balanceOf(address(this)), "Insufficient tokens to claim.");

        // check cooldown
        uint lastClaim = lastTimeStamps[msg.sender];
        if (lastClaim > 0) { // not first time
            uint idle = block.timestamp - lastClaim;
            uint cd = calcCooldown(msg.sender);
            if (idle < cd) // claim too fast
                require(false, string.concat(string.concat("Please try again in ", Strings.toString(cd - idle)), " seconds."));
        }
        // transfer token
        lastTimeStamps[msg.sender] = block.timestamp;
        require(token.transfer(msg.sender, calcAmount), "Token transfer failed.");
    }

}
