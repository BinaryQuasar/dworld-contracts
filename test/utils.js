// From: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/test/helpers/expectThrow.js
const assertThrow = async promise => {
    try {
        await promise;
    } catch (error) {
        // TODO: Check jump destination to destinguish between a throw
        //       and an actual invalid jump.
        const invalidOpcode = error.message.search('invalid opcode') >= 0;
        // TODO: When we contract A calls contract B, and B throws, instead
        //       of an 'invalid jump', we get an 'out of gas' error. How do
        //       we distinguish this from an actual out of gas event? (The
        //       testrpc log actually show an 'invalid jump' event.)
        const outOfGas = error.message.search('out of gas') >= 0;
        const revert = error.message.search('revert') >= 0;
        assert(
            invalidOpcode || outOfGas || revert,
            'Expected throw, got \'' + error + '\' instead',
        );
        return;
    }
    assert.fail('Expected throw not received');
};

const assertRevert = async promise => {
    try {
        await promise;
        assert.fail('Expected revert not received');
    } catch (error) {
        const revertFound = error.message.search('revert') >= 0;
        assert(revertFound, `Expected "revert", got ${error} instead`);
    }
};

// From: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/test/helpers/latestTime.js
const latestTime = function() {
    return web3.eth.getBlock('latest').timestamp;
}

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
        if (err1) return reject(err1);

            web3.currentProvider.sendAsync({
                jsonrpc: '2.0',
                method: 'evm_mine',
                id: id + 1,
            }, (err2, res) => {
                return err2 ? reject(err2) : resolve(res);
            });
        });
    });
}

/**
 * Beware that due to the need of calling two separate testrpc methods and rpc calls overhead
 * it's hard to increase time precisely to a target point so design your test to tolerate
 * small fluctuations from time to time.
 *
 * @param target time in seconds
 */
const increaseTimeTo =  function(target) {
    let now = latestTime();
    if (target < now) throw Error(`Cannot increase current time(${now}) to a moment in the past(${target})`);
    let diff = target - now;
    return increaseTime(diff);
}

const duration = {
    seconds: function (val) { return val; },
    minutes: function (val) { return val * this.seconds(60); },
    hours: function (val) { return val * this.minutes(60); },
    days: function (val) { return val * this.hours(24); },
    weeks: function (val) { return val * this.days(7); },
    years: function (val) { return val * this.days(365); },
};

module.exports = {
    assertThrow,
    assertRevert,
    latestTime,
    increaseTime,
    increaseTimeTo,
    duration
};
