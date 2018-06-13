pragma solidity ^0.4.24;

import './CPToken.sol';
import './DPIcoWhitelist.sol';
import './Tiers.sol';
import './SafeMath.sol';
import './CappedCrowdsale.sol';
import './FinalizableCrowdsale.sol';
import './Ownable.sol';
import './Pausable.sol';

contract CPCrowdsale is CappedCrowdsale, FinalizableCrowdsale, Pausable {
    using SafeMath for uint256;

    DPIcoWhitelist private aw;
    Tiers private at;
    mapping (address => bool) private hasPurchased; // has whitelist address purchased already
    uint256 public whitelistEndTime;
    uint256 public maxWhitelistPurchaseWei;
    uint256 public openWhitelistEndTime;

    constructor(uint256 _startTime, uint256 _endTime, uint256 _whitelistEndTime, uint256 _openWhitelistEndTime, address _wallet, address _tiersContract, address _whitelistContract, address _airdropWallet, address _advisorWallet, address _stakingWallet, address _privateSaleWallet)
        CappedCrowdsale(45000 ether) // crowdsale capped at 45000 ether
        FinalizableCrowdsale()
        Crowdsale(_startTime, _endTime, 1, _wallet)  // rate = 1 is a dummy value; we use tiers instead
        public
    {
        token.mint(_wallet, 23226934 * (10 ** 18));
        token.mint(_airdropWallet, 5807933 * (10 ** 18));
        token.mint(_advisorWallet, 5807933 * (10 ** 18));
        token.mint(_stakingWallet, 11615867 * (10 ** 18));
        token.mint(_privateSaleWallet, 36000000 * (10 ** 18));

        aw = DPIcoWhitelist(_whitelistContract);
        require (aw.numUsers() > 0);
        at = Tiers(_tiersContract);
        whitelistEndTime = _whitelistEndTime;
        openWhitelistEndTime = _openWhitelistEndTime;
        weiRaised = 18000 ether; // 18K ether was sold during presale
        maxWhitelistPurchaseWei = (cap.sub(weiRaised)).div(aw.numUsers());
    }

    // Public functions
    function buyTokens(address beneficiary) public payable whenNotPaused {
        uint256 weiAmount = msg.value;

        require(beneficiary != 0x0);
        require(validPurchase());
        require(!isWhitelistPeriod()
             || whitelistValidPurchase(msg.sender, beneficiary, weiAmount));
        require(!isOpenWhitelistPeriod()
             || openWhitelistValidPurchase(msg.sender, beneficiary));

        hasPurchased[beneficiary] = true;

        uint256 tokens = at.calculateTokens(weiAmount, weiRaised);
        weiRaised = weiRaised.add(weiAmount);
        token.mint(beneficiary, tokens);
        emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
        forwardFunds();
    }

    // Internal functions

    function createTokenContract() internal returns (MintableToken) {
        return new CPToken();
    }

    /**
     * @dev Overriden to add finalization logic.
     * Mints remaining tokens to dev wallet
     */
    function finalization() internal {
        uint256 remainingWei = cap.sub(weiRaised);
        if (remainingWei > 0) {
            uint256 remainingDevTokens = at.calculateTokens(remainingWei, weiRaised);
            token.mint(wallet, remainingDevTokens);
        }
        CPToken(token).endSale();
        token.finishMinting();
        super.finalization();
    }

    // Private functions

    // can't override `validPurchase` because need to pass additional values
    function whitelistValidPurchase(address buyer, address beneficiary, uint256 amountWei) private constant returns (bool) {
        bool beneficiaryPurchasedPreviously = hasPurchased[beneficiary];
        bool belowMaxWhitelistPurchase = amountWei <= maxWhitelistPurchaseWei;
        return (openWhitelistValidPurchase(buyer, beneficiary)
                && !beneficiaryPurchasedPreviously
                && belowMaxWhitelistPurchase);
    }

    // @return true if `now` is within the bounds of the whitelist period
    function isWhitelistPeriod() private constant returns (bool) {
        return (now <= whitelistEndTime && now >= startTime);
    }

    // can't override `validPurchase` because need to pass additional values
    function openWhitelistValidPurchase(address buyer, address beneficiary) private constant returns (bool) {
        bool buyerIsBeneficiary = buyer == beneficiary;
        bool signedup = aw.isSignedUp(beneficiary);
        return (buyerIsBeneficiary && signedup);
    }

    // @return true if `now` is within the bounds of the open whitelist period
    function isOpenWhitelistPeriod() private constant returns (bool) {
        bool cappedWhitelistOver = now > whitelistEndTime;
        bool openWhitelistPeriod = now <= openWhitelistEndTime;
        return cappedWhitelistOver && openWhitelistPeriod;
    }

}
