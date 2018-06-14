pragma solidity ^0.4.24;

import './MintableToken.sol';
import './LimitedTransferToken.sol';

contract CPToken is MintableToken, LimitedTransferToken {
    string public name = "BLOCKMASON CREDIT PROTOCOL TOKEN";
    string public symbol = "BCPT";
    uint256 public decimals = 18;

    bool public saleOver = false;

    constructor() public {
    }

    function endSale() public onlyOwner {
        require (!saleOver);
        saleOver = true;
    }

    /**
     * @dev returns all user's tokens if time >= releaseTime
     */
    function transferableTokens(address holder, uint64) public constant returns (uint256) {
        if (saleOver)
            return balanceOf(holder);
        else
            return 0;
    }

}
