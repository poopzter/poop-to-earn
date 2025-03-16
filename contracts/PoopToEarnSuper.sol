// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PoopToEarnSuper is Ownable {

    address private tokenAddr = 0x3AA14Ed2d1A65a58DF0237fA84239F97fF4E9B42; // ***TODO*** POOP
    address private nftAddr = 0x8E56343adAFA62DaC9C9A8ac8c742851B0fb8b03; // Bored Town
    uint256 public claimAmount = 1 * (10**18);
    uint256 public claimMax = 888 * (10**18);
    uint256 public bonusAmount = 0 * (10**18);
    uint256 public cooldown = 60; // seconds
    uint256 public bCooldown = 30; // seconds
    bool public claimActive = true;

    IERC20 public token;
    IERC721 public nft;
    mapping(address => uint256) public claims;
    mapping(address => uint256) public lastTimeStamps;

    constructor(address initialOwner) Ownable(initialOwner) {
        token = IERC20(tokenAddr);
        nft = IERC721(nftAddr);
    }

    // manage contract (owner)
    function setToken(address _addr) external onlyOwner { token = IERC20(_addr); }
    function setNFT(address _addr) external onlyOwner { nft = IERC721(_addr); }
    function setClaimAmount(uint256 _amount) external onlyOwner { claimAmount = _amount; }
    function setClaimMax(uint256 _amount) external onlyOwner { claimMax = _amount; }
    function setBonusAmount(uint256 _amount) external onlyOwner { bonusAmount = _amount; }
    function setCooldown(uint256 _cooldown) external onlyOwner { cooldown = _cooldown; }
    function setCooldownB(uint256 _cooldown) external onlyOwner { bCooldown = _cooldown; }
    function toggleClaim() external onlyOwner { claimActive = !claimActive; }
    function withdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No token to withdraw.");
        require(token.transfer(msg.sender, balance), "Token transfer failed.");
    }

    // claim token
    function calcClaimAmount(address addr) public view returns (uint256) {
        if (nft.balanceOf(addr) > 0) // holder
            return claimAmount + bonusAmount;
        else // non-holder
            return claimAmount;
    }
    function calcCooldown(address addr) public view returns (uint256) {
        if (nft.balanceOf(addr) > 0)
            return bCooldown;
        else
            return cooldown;
    }
    function claim() external {
        // check active
        require(claimActive, "Claim is not activated.");

        // check token balance
        uint256 calcAmount = calcClaimAmount(msg.sender);
        require(calcAmount <= token.balanceOf(address(this)), "Insufficient tokens to claim.");
        require(claims[msg.sender] + calcAmount <= claimMax, "Claim limit reached.");

        // check cooldown
        uint256 lastClaim = lastTimeStamps[msg.sender];
        if (lastClaim > 0) { // not first time
            uint256 idle = block.timestamp - lastClaim;
            uint256 cd = calcCooldown(msg.sender);
            if (idle < cd) // claim too fast
                require(false, string.concat("Please try again in ", Strings.toString(cd - idle), " seconds."));
        }
        // transfer token
        require(token.transfer(msg.sender, calcAmount), "Token transfer failed.");
        claims[msg.sender] += calcAmount;
        lastTimeStamps[msg.sender] = block.timestamp;
    }

}
