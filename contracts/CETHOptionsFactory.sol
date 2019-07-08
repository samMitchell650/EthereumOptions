pragma solidity ^0.5.0;

import "./CETHCallOption.sol";
import "./CETHPutOption.sol";

contract CETHOptionsFactory {
    
    mapping(uint256 => mapping(uint256 => address)) private _call_option_contracts;
    mapping(uint256 => mapping(uint256 => address)) private _put_option_contracts;

    event CallOptionContractCreated(address indexed contract_address, uint256 expiration_timestamp, uint256 strike);
    event PutOptionContractCreated(address indexed contract_address, uint256 expiration_timestamp, uint256 strike);
    
    function callOptionContract(uint256 expiration_timestamp, uint256 strike) public view returns (address) {
        return _call_option_contracts[expiration_timestamp][strike];
    }
    
    function putOptionContract(uint256 expiration_timestamp, uint256 strike) public view returns (address) {
        return _put_option_contracts[expiration_timestamp][strike];
    }
    
    function createCallOptionContract(uint256 expiration_timestamp, uint256 strike) public returns (bool success) {
        
        // check valid expiration
        require(expiration_timestamp >= now, "Invalid expiration.");
        
        // check the contract was not already created
        require(_call_option_contracts[expiration_timestamp][strike] == address(0), "Contract already created.");
        
        // create new call option contract with the given parameters
        CETHCallOption call_option_contract = new CETHCallOption(expiration_timestamp, strike, "CETH Call Contract", "CETHCall");

        address call_option_contract_address = address(call_option_contract);

        _call_option_contracts[expiration_timestamp][strike] = call_option_contract_address;

        emit CallOptionContractCreated(call_option_contract_address, expiration_timestamp, strike);
        
        return true;
    }
    
    function createPutOptionContract(uint256 expiration_timestamp, uint256 strike) public returns (bool success) {

        // check valid expiration
        require(expiration_timestamp >= now, "Invalid expiration.");
        
        // check the contract was not already created
        require(_put_option_contracts[expiration_timestamp][strike] == address(0), "Contract already created.");
        
        // create new put option contract with the given parameters
        CETHPutOption put_option_contract = new CETHPutOption(expiration_timestamp, strike, "CETH Put Contract", "CETHPut");

        address put_option_contract_address = address(put_option_contract);

        _put_option_contracts[expiration_timestamp][strike] = put_option_contract_address;

        emit PutOptionContractCreated(put_option_contract_address, expiration_timestamp, strike);
        
        return true;
    }
}