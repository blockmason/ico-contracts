/* helpers */
const BigNumber = web3.BigNumber;
const toWei     = web3.toWei;
const fromWei   = web3.fromWei;

exports.BigNumber = BigNumber;
exports.toWei = toWei;
exports.fromWei = fromWei;

// Increases testrpc time by the passed duration in seconds
const increaseTime = function(duration) {
    const id = Date.now();

    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [duration],
            id: id,
        }, err1 => {
            if (err1) return reject(err1)

            web3.currentProvider.sendAsync({
                jsonrpc: '2.0',
                method: 'evm_mine',
                id: id + 1,
            }, (err2, res) => {
                return err2 ? reject(err2) : resolve(res);
            });
        });
    });
};
exports.increaseTime = increaseTime;

/**
 * Beware that due to the need of calling two separate testrpc methods and rpc
 * calls overhead it's hard to increase time precisely to a target point so
 * design your test to tolerate small fluctuations from time to time.
 *
 * @param target time in seconds
 */
exports.increaseTimeTo = function(target) {
    let now = latestTime();
    if (target < now) throw Error(`Cannot increase current time(${now}) to a moment in the past(${target})`);
    let diff = target - now;
    return increaseTime(diff);
};

exports.duration = {
    seconds: function(val) { return val},
    minutes: function(val) { return val * this.seconds(60) },
    hours:   function(val) { return val * this.minutes(60) },
    days:    function(val) { return val * this.hours(24) },
    weeks:   function(val) { return val * this.days(7) },
    years:   function(val) { return val * this.days(365) }
};

exports.EVMThrow = 'VM Exception while processing transaction: revert';

exports.advanceBlock = function() {
    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_mine',
            id: Date.now()
        }, (err, res) => {
            return err ? reject(err) : resolve(res);
        });
    });
};

// Advances the block number so that the last mined block is `number`.
exports.advanceToBlock = async function(number) {
    if (web3.eth.blockNumber > number) {
        throw Error(`block number ${number} is in the past (current is ${web3.eth.blockNumber})`);
    }

    while (web3.eth.blockNumber < number) {
        await advanceBlock();
    }
};

const latestTime = function() {
    return web3.eth.getBlock('latest').timestamp;
};
exports.latestTime = latestTime;

const e2Wei = function(n) {
    return new BigNumber(toWei(n, 'ether'));
};
exports.e2Wei = e2Wei;

exports.eBal = function(account) {
    return web3.fromWei(web3.eth.getBalance(account), "ether");
};
exports.tokenFromDec = function(balance) {
    return web3.fromWei(balance, "ether");
};

exports.tokenToDec = function(tokenAmt) {
    return web3.toWei(tokenAmt, "ether");
};

// implementation of `calculateTokens` function in
// `CPCrowdsale.sol`, written in JS
exports.calculateTokens = function(tiers, startWei, weiAmt) {
    var weiRaised = web3.toBigNumber(startWei);
    var amtLeft = web3.toBigNumber(weiAmt);
    var tokens = web3.toBigNumber(0);
    var capLeft;
    for (var i = 0; i < tiers.length; i++) {
        var rate = web3.toBigNumber(tiers[i].rate);
        var cap = web3.toBigNumber(tiers[i].amountCap);
        capLeft = cap.minus(weiRaised);
        if (capLeft.gt(0)) {
            if (amtLeft.lte(capLeft)) {
                tokens = tokens.plus(amtLeft.times(rate));
                break;
            }
            tokens = tokens.plus(capLeft.times(rate));
            weiRaised = weiRaised.plus(capLeft);
            amtLeft = amtLeft.minus(capLeft);
        }
    }
    return tokens;
};
