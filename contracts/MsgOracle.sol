pragma solidity ^0.5.12;

import "node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
@title MsgOracle
@author Rinke Hendriksen <rinke@ethswarm.org>
@notice Set the honey prices for various messages in Swarm
@dev This on-chain msgOracle must be queried by a swarm-node. By reading the event logs, a node is able to construct the following object:
msgPrices: {TTL, prices: {swarmMsgX: [<validFrom0, price>, <validFromN, price>], swarmMsgX: [<validFrom0, price>, <validFromN, price>]}}.
this object expires after TTL seconds. The prices object holds all message types with their respective price arrays.
In the price array of a message, multiple prices can be quoted. The chosen price is the most-recent price.
*/
contract MsgOracle is Ownable {
    using SafeMath for uint256;
    /*
    TTL is the TTL applied by nodes (how long is a query to this oracle valid)
    oldTTL is used internally when lastUpdated is not longer than oldTTL ago,
    furthermore, we don't allow updating TTL when lastUpdated is not TTL seconds ago.
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
        require(lastUpdated.add(TTL) <= now, "MsgOracleOwner: TTL less than TTL seconds ago updated");
        oldTTL = TTL;
        TTL = _TTL;
        lastUpdated = now;
        emit LogNewTTL(_TTL);
    }

    /**
    @notice Sets a new price for a swarmMsg.
    @dev Emits a LogSetMsgPrice which allows a swarm-node to insert a new entry in the prices object.
    The function ensures that validFrom is at least TTL (or oldTTL, when TTL is updated recently) seconds in the future
    @param swarmMsg the bytes32 representation of the swarmMsg for which the price is quoted.
    @param price the price of a particular swarmMsg, valid from validFrom onwards
    @param validFrom the UNIX timestamp from which the newPrice for the swarmMsg is active.
    */
    function setMsgPrice(bytes32 swarmMsg, uint256 price, uint256 validFrom) public onlyOwner {
        // if lastUpdated is less than oldTTL ago, we have to compare validFrom against oldTTL`
        if(lastUpdated > now - oldTTL) {
            require(validFrom >= now + oldTTL, "MsgOracle: validFrom not oldTTL seconds in the future");
        } else {
            require(validFrom >= now + TTL, "MsgOracle: validFrom not TTL seconds in the future");
        }
        emit LogSetMsgPrice(swarmMsg, price, validFrom);
    }

    /**
    @notice Instructs a node to disregards a previously emitted LogSetMsgPrice
    @dev If a LogNewMsgPrice event exists with the same arguments before this function is called, the LogSetMsgPrice (and its effect on the prices object)
    should be disregarded after TTL seconds.
    @param swarmMsg Match with swarmMsg from LogSetMsgPrice(swarmMsg, price, validFrom)
    @param price Match with price from LogSetMsgPrice(swarmMsg, price, validFrom)
    @param validFrom Match with validFrom from LogSetMsgPrice(swarmMsg, price, validFrom)
     */
    function revertMsgPrice(bytes32 swarmMsg, uint256 price, uint256 validFrom) public onlyOwner {
        emit LogRevertMsgPrice(swarmMsg, price, validFrom);
    }
}