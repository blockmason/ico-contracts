#!/bin/bash
# The code should launch a console that is the owner of a whilelist contract
# and a crowdsale contract. The contract functions can be tested in the repl
# thus:
# > var app
# > CPCrowdsale.deployed().then(function(instance) { app = instance; })
# > app.tierIndexByWeiAmount(web3.toWei(39000, "ether"))
# >>> { [String: '4'] s: 1, e: 0, c: [ 4 ] }
# > app.calculateTokens(web3.toWei(10000, "ether"), web3.toWei(18000))
# >>> { [String: '1.425e+25'] s: 1, e: 25, c: [ 142500000000 ] }

function cleanup {
  kill -9 "${ganache_pid}"
}

trap cleanup EXIT

ganache \
  -p 8547 \
&

ganache_pid=$!
echo "Started ganache, pid ${ganache_pid}"

truffle compile
truffle migrate --reset --network console
truffle console --network console
