pragma solidity ^0.4.13;

import "./RecurrentAllowanceToken.sol";
import "./ReleasableToken.sol";
import "./MintableToken.sol";
import "./BurnableToken.sol";


contract YBTToken is RecurrentAllowanceToken, ReleasableToken, MintableToken, BurnableToken {

    string public name;
    string public symbol;
    uint public decimals;

    function YBTToken(string _name, string _symbol, uint _initialSupply, uint _decimals, bool _mintable, bool _released) {

        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        require(_initialSupply > 0 || _mintable);
        totalSupply = _initialSupply;
        released = _released;

        decimals = _decimals;

        // Create initially all balance on the team multisig
        balances[owner] = totalSupply;

        if (totalSupply > 0) {
            Mint(owner, totalSupply);
        }

        // No more new supply allowed after the token creation
        if (!_mintable) {
            mintingFinished = true;
        }
    }

    function updateInfo(string _name, string _symbol) onlyOwner public {
        name = _name;
        symbol = _symbol;
    }
}
