pragma solidity ^0.4.11;

import "../ownership/Ownable.sol";
import "./IApprovalManager.sol";


contract BillingApprovalManager is Ownable, IApprovalManager {

   struct AllowanceDef {
       uint256 ind;
       address provider;

   }
   mapping (address => bool) public  providers; 

   mapping (address => address[]) public allowanceProviders;

  // mapping (address => )

   function approve(
        address provider, 
        address spender, 
        uint256 value, 
        bytes payload) public returns (bool) {

        require(providers[provider]);

        require(provider.call(payload));

    }
}