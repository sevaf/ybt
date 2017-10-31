pragma solidity ^0.4.11;

import "./ERC20.sol";
import "../ownership/Ownable.sol";

/**
 * Define interface for releasing the token transfer after a successful crowdsale.
 */
contract ReleasableToken is ERC20, Ownable {

    /** A crowdsale contract can release us to the wild if ICO success. If false we are are in transfer lock up period.*/
    bool public released = false;

    /** Map of agents that are allowed to transfer tokens regardless of the lock down period. These are crowdsale contracts and possible the team multisig itself. */
    mapping (address => bool) public transferAgents;

    /**
    * Limit token transfer until the crowdsale is over.
    *
    */
    modifier canTransfer(address _sender) {
        require(released || transferAgents[_sender]);
        _;
    }

    /**
    * Owner can allow a particular address (a crowdsale contract) to transfer tokens despite the lock up period.
    */
    function setTransferAgent(address addr, bool state) onlyOwner public {
        require(!released);
        transferAgents[addr] = state;
    }

    function getTransferAgentState(address addr) onlyOwner public constant returns (bool state) {
        return transferAgents[addr];
    }

    /**
    * One way function to release the tokens to the wild.
    *
    * Can be called only from the release agent that is the final ICO contract. It is only called if the crowdsale has been success (first milestone reached).
    */
    function releaseTokenTransfer() public onlyOwner {
        released = true;
    }

    function transfer(address _to, uint _value) canTransfer(msg.sender) returns (bool success) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) canTransfer(_from) returns (bool success) {
        return super.transferFrom(_from, _to, _value);
    }

}