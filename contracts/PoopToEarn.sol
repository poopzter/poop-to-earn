// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PoopToEarn is Ownable {

    address private tokenAddr = 0x3AA14Ed2d1A65a58DF0237fA84239F97fF4E9B42; // BLOBz
    address private nftAddr = 0x8E56343adAFA62DaC9C9A8ac8c742851B0fb8b03; // Bored Town
    uint public claimAmount = 888 * (10**18);
    uint public bonusAmount = 888 * (10**18);
    uint public cooldown = 60; // seconds
    bool public claimActive = true;

    IERC20 public token;
    IERC721 public nft;
    mapping(address => uint) public lastTimeStamps;

    constructor(address initialOwner) Ownable(initialOwner) {
        token = IERC20(tokenAddr);
        nft = IERC721(nftAddr);
    }

    // manage contract (owner)
    function setToken(address _addr) external onlyOwner { token = IERC20(_addr); }
    function setNFT(address _addr) external onlyOwner { nft = IERC721(_addr); }
    function setClaimAmount(uint _amount) external onlyOwner { claimAmount = _amount; }
    function setBonusAmount(uint _amount) external onlyOwner { bonusAmount = _amount; }
    function setCooldown(uint _cooldown) external onlyOwner { cooldown = _cooldown; }
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
            if (idle < cooldown) // claim too fast
                require(false, string.concat(string.concat("Please try again in ", Strings.toString(cooldown - idle)), " seconds."));
        }
        // transfer token
        lastTimeStamps[msg.sender] = block.timestamp;
        require(token.transfer(msg.sender, calcAmount), "Token transfer failed.");
    }

}
