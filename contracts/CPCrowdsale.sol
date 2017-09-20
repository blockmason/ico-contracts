pragma solidity 0.4.15;

import './CPToken.sol';
import './AbstractWhitelist.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/crowdsale/CappedCrowdsale.sol';
import 'zeppelin-solidity/contracts/crowdsale/FinalizableCrowdsale.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';

contract CPCrowdsale is CappedCrowdsale, FinalizableCrowdsale, Pausable {
    using SafeMath for uint256;

    bool public offlineSaleDone; // when true, owner can no longer pre-mint
    uint public numOfflineTokensNoDec;

    uint256 public cpCap = 45000 ether;
    uint256 public constant dummyRate = 1;

    uint256 public presaleWeiSold = 18000 ether;
    uint256 public totalTokens = 116158667;
    uint256 public publicTokens = 33695200;
    uint256 public initialOwnerTokens = totalTokens - publicTokens;

    uint256 public currTier;
    uint256 public constant numTiers = 6;
    uint256[6] public tierAmountCaps =  [ presaleWeiSold
                                        , presaleWeiSold + 5000 ether
                                        , presaleWeiSold + 10000 ether
                                        , presaleWeiSold + 15000 ether
                                        , presaleWeiSold + 21000 ether
                                        , cpCap
                                        ];
    uint256[6] public tierRates = [ 2000 // tierRates[0] should never be used, but it is accurate
                                  , 1500 // Tokens are purchased at a rate of 1050-1500
                                  , 1350 // per Eth, depending on purchase tier.
                                  , 1250 // tierRates[i] is the purchase rate of tier_i
                                  , 1150
                                  , 1050
                                  ];

    AbstractWhitelist private aw;
    mapping (address => bool) private hasPurchased; // has whitelist address purchased already
    uint256 public whitelistEndTime;
    uint256 public maxWhitelistPurchaseWei;
    uint256 public openWhitelistEndTime;

    function CPCrowdsale(uint256 _startTime, uint256 _endTime, uint256 _whitelistEndTime, uint256 _openWhitelistEndTime, address _wallet, address _whitelistContract)
        CappedCrowdsale(cpCap)
        FinalizableCrowdsale()
        Crowdsale(_startTime, _endTime, dummyRate, _wallet)  // rate is a dummy value; we use tiers instead
    {
        numOfflineTokensNoDec = 0;
        token.mint(_wallet, initialOwnerTokens);
        aw = AbstractWhitelist(_whitelistContract);
        require (aw.numUsers() > 0);
        currTier = 0;
        whitelistEndTime = _whitelistEndTime;
        openWhitelistEndTime = _openWhitelistEndTime;
        weiRaised = presaleWeiSold;
        setTier(weiRaised);
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

        uint256 tokens = calculateTokens(weiAmount, weiRaised, currTier, 0);
        weiRaised = weiRaised.add(weiAmount);
        setTier(weiRaised);

        token.mint(beneficiary, tokens);
        TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    // Internal functions

    function createTokenContract() internal returns (MintableToken) {
        return new CPToken(endTime);
    }

    /**
     * @dev Overriden to add finalization logic.
     * Mints remaining tokens to dev wallet
     */
    function finalization() internal {
        uint256 remainingWei = cap.sub(weiRaised);
        uint256 remainingDevTokens = calculateTokens(remainingWei, weiRaised, currTier, 0);
        token.mint(wallet, remainingDevTokens);
        CPToken(token).endSale();
        token.finishMinting();
        super.finalization();
    }


    // Private functions

    function setTier(uint256 _weiRaised) private {
        while(_weiRaised > tierAmountCaps[currTier]) {
            currTier = currTier.add(1);
            assert(currTier < numTiers);
        }
    }

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

    /**
     * @dev Calculates how many tokens a given amount of wei can buy
     * Takes into account tiers of purchase bonus
     * Recursive, but depth is limited to the number of tiers, which is 6
     */
    function calculateTokens(uint256 _amountWei, uint256 _weiRaised, uint256 _tier, uint256 tokenAcc) private constant returns (uint256) {
        assert(_tier < numTiers);
        uint256 currRate = tierRates[_tier];
        uint256 tierAmountLeftWei = tierAmountCaps[_tier].sub(_weiRaised);
        if (_amountWei <= tierAmountLeftWei) {
            return tokenAcc.add(_amountWei.mul(currRate));
        }
        else {
            return calculateTokens(_amountWei.sub(tierAmountLeftWei), _weiRaised.add(tierAmountLeftWei), _tier.add(1), tokenAcc.add(tierAmountLeftWei.mul(currRate)));
        }
    }

}
