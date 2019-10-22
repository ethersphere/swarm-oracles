pragma solidity ^0.5.10;

import "node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
@title MsgOracle
@author Rinke Hendriksen <rinke@ethswarm.org>
@notice Set the honey prices for various messages in Swarm
@dev This on-chain msgOracle must be queried by a swarm-node. A query for all msgPrices simultaneously should result in the following object:
msgPrices: {TTL, prices: {swarmMsgX: [<validFrom0, price>, <validFromN, price>], swarmMsgX: [<validFrom0, price>, <validFromN, price>]}}.
this object expires after TTL seconds. The prices object holds all message types with their respective price arrays.
In the price array of a message, multiple prices can be quoted. The chosen price is the most-recent price.
*/
contract MsgOracle is Ownable {
    /*
    currentTTL is the TTL applied by nodes (how long is a query to this oracle valid)
    oldTTL is used internally when lastUpdated is not longer than oldTTL ago,
    furthermore, we don't allow updating TTL when lastUpdated is not currentTTL seconds ago.
    */
    uint256 public TTL;
    uint256 private oldTTL;
    uint256 private lastUpdated;

    event LogNewTTL(uint256 TTL);
    event LogSetMsgPrice(bytes32 indexed swarmMsg, uint256 price, uint256 validFrom);
    event LogRevertMsgPrice(bytes32 indexed swarmMsg, uint256 price, uint256 validFrom);
    /**
    @notice Sets an initial value of TTL and sets the owner
    @dev The owner can be a EOA or a smart-contract (with any arbitrary governance structure) which can call all functions from this contract
    @param _TTL The initial TTL, effective immediately.
    */
    constructor(uint256 _TTL) public Ownable() {
        TTL = _TTL;
        lastUpdated = now;
        emit LogNewTTL(TTL);
    }

    /**
    @notice Sets a new value of TTL.
    @dev The TTL is the duration in seconds of the validity of a query to this oracle.
    We advise querying the oracle again at a fraction of TTL (e.g. 50%).
    Sets the TTL from the msgPrices object {TTL, prices}
    Warning: the owner is responsible for ensuring that we don't update TTL to an unreasonably high value and hereby deadlock the contract for this period.
    @param _TTL TTL which will be effective after TTL seconds
    */
    function newTTL(uint256 _TTL) public onlyOwner {
        require(lastUpdated + TTL <= now, "MsgOracleOwner: TTL less than TTL seconds ago updated");
        oldTTL = TTL;
        TTL = _TTL;
        lastUpdated = now;
        emit LogNewTTL(_TTL);
    }

    /**
    @notice sets a new price for a swarmMsg.
    @dev sets the prices of the msgPrices object {TTL, prices}.
    Prices is an object consisting of a swarmMsg objects (prices: {swarmMsgX, swarmMsgY}) for every unique swarmMsg emitted.
    SwarmMsg is an array of validFrom, price tuples (swarmMsg: [<validFrom0, price>, <validFromN, price>]).
    a new msgPrice is effective after from validFrom onwards.
    @param swarmMsg the bytes32 representation of the swarmMsg for which the price is quoted.
    @param price the price of a particular swarmMsg, valid from validFrom onwards
    @param validFrom the UNIX timestamp from which the newPrice for the swarmMsg is active.
    */
    function setMsgPrice(bytes32 swarmMsg, uint256 price, uint256 validFrom) public onlyOwner {
        if(lastUpdated - oldTTL <= now) {
            require(validFrom >= now + oldTTL, "MsgOracle: validFrom not oldTTL seconds in the future");
        } else {
            require(validFrom >= now + TTL, "MsgOracle: validFrom not TTL seconds in the future");
        }
        emit LogSetMsgPrice(swarmMsg, price, validFrom);
    }

    /**
    @notice reverts a previously emitted price of a swarmMsg
    @dev if a LogNewMsgPrice event exists with the same arguments before this function is called, the LogSetMsgPrice should be disregarded after TTL seconds.
    @param swarmMsg match with swarmMsg from LogSetMsgPrice(swarmMsg, price, validFrom)
    @param price match with swarmMsg from LogSetMsgPrice(swarmMsg, price, validFrom)
    @param validFrom match with swarmMsg from LogSetMsgPrice(swarmMsg, price, validFrom)
     */
    function revertMsgPrice(bytes32 swarmMsg, uint256 price, uint256 validFrom) public onlyOwner {
        emit LogRevertMsgPrice(swarmMsg, price, validFrom);
    }
}