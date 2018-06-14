pragma solidity ^0.4.24;

import './SafeMath.sol';

contract Tiers {
  using SafeMath for uint256;

  uint256 public cpCap = 45000 ether;
  uint256 public presaleWeiSold = 18000 ether;

  uint256[6] public tierAmountCaps =  [ presaleWeiSold
                                      , presaleWeiSold + 5000 ether
                                      , presaleWeiSold + 10000 ether
                                      , presaleWeiSold + 15000 ether
                                      , presaleWeiSold + 21000 ether
                                      , cpCap
                                      ];
  uint256[6] public tierRates = [ 2000 // tierRates[0] should never be used, but it is accurate
                                , 1500 // Tokens are purchased at a rate of 105-150
                                , 1350 // per deciEth, depending on purchase tier.
                                , 1250 // tierRates[i] is the purchase rate of tier_i
                                , 1150
                                , 1050
                                ];

    function tierIndexByWeiAmount(uint256 weiLevel) public constant returns (uint256) {
        require(weiLevel <= cpCap);
        for (uint256 i = 0; i < tierAmountCaps.length; i++) {
            if (weiLevel <= tierAmountCaps[i]) {
                return i;
            }
        }
    }

    /**
     * @dev Calculates how many tokens a given amount of wei can buy at
     * a particular level of weiRaised. Takes into account tiers of purchase
     * bonus
     */
    function calculateTokens(uint256 _amountWei, uint256 _weiRaised) public constant returns (uint256) {
        uint256 currentTier = tierIndexByWeiAmount(_weiRaised);
        uint256 startWeiLevel = _weiRaised;
        uint256 endWeiLevel = _amountWei.add(_weiRaised);
        uint256 tokens = 0;
        for (uint256 i = currentTier; i < tierAmountCaps.length; i++) {
            if (endWeiLevel <= tierAmountCaps[i]) {
                tokens = tokens.add((endWeiLevel.sub(startWeiLevel)).mul(tierRates[i]));
                break;
            } else {
                tokens = tokens.add((tierAmountCaps[i].sub(startWeiLevel)).mul(tierRates[i]));
                startWeiLevel = tierAmountCaps[i];
            }
        }
        return tokens;
    }

}
