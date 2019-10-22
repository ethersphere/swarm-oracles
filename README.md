# Introduction
The msgOracle smart-contracts include a proposal for the `messageToHoneyContract` as described by <SWIP reference here>. Furthermore, a simple governance scheme is included which allows non-impactfull interactions (such as changing a price within boundaries) with the `messageToHoneyContract` to be performed by one address, while impactful interactions need an approval of a certain percentage of Swarm stakeholders/developers.

# MsgOracle
The MsgOracle is a smart-contract which inherits functionalities from [openzeppelin-solidity/ownable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/ownership/Ownable.sol). As such, it can define an owner and limit access to certain function to be only performed by the owner. 
By reading the events emitted by this smart-contract (in particular: `LogNewTTL`, `LogSetMsgPrice` and `LogRevertMsgPrice`), nodes know the latest value of all message prices in Swarm and be guaranteed that their peers apply the same prices.

## Description of public functions
The `msgOracle` exposes the following functions:

### TTL
- Getter function, which returns the Time To Live (`TTL`) for the contract. `TTL` signals to the nodes how long a response from the oracle is guaranteed valid; if a node uses an oracle response which is older than `TTL` seconds, it is not guaranteed to be correct anymore.

### owner
- Getter function, which return the current owner of the contract.

### newTTL 
- Sets a new Time To Live (`TTL`). `TTL` can only be updated after `TTL` seconds after it was set. 
- Stores the previous value of `TTL` .
- Stores when the function was called.
- Emits a `LogNewTTL(uint256 TTL)` event on which nodes can listen to be informed on changes in `TTL`.
- only callable by `owner`

### setMsgPrice 
- informs the node about a new `price` for a particular `swarmMsg`, in effect from a certain date (`validFrom`)
- requires validFrom to be at least `TTL` seconds in the future. If `TTL` has been recently updated (not longer than the old value of `TTL` seconds ago), we use the old value of `TTL`.
- Emits a `LogSetMsgPrice(bytes32 indexed swarmMsg, uint256 price, uint256 validFrom)` event.
- only callable by `owner`

### revertMsgPrice
- informs the node to ignore a previous emitted `LogSetMsgPrice` event with the same arguments as the `LogRevertMsgPrice(bytes32 indexed swarmMsg, uint256 price, uint256 validFrom)` event, emitted by this function. 
- only callable by `owner`

### renounceOwnership
- Set's the ownership of this smart-contract to the 0 address, which will render all functionalities of this smart-contract forever useless. 
- emits an `OwnershipTransferred(address indexed previousOwner, address indexed newOwner)` event.
- only callable by `owner`

### transferOwnership
- Set's the ownership of this smart-contract to another address. Meant for updating the governance around the oracle.
- emits an `OwnershipTransferred(address indexed previousOwner, address indexed newOwner)` event.
- only callable by `owner`
