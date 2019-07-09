# CETH Options

## Table of Contents
- [Overview](#Overview)
- [Factory Contract](#Factory)
- [Option Contracts](#Options)

## Overview
CETH options use Compound to earn interest on collateral in the contract until contributions are claimed by option writers after expiration.

Suppose Alice wants to write a put for ETH at a 300 DAI strike and an expiration of one month. Put options are simply an obligation to buy an asset at a predefined price, so she deposits 300 DAI into the CETH option contract to enforce her obligation. Her 300 DAI is immediately used to mint cDAI from Compound, now earning Alice interest at the market rate. Alice also has her freshly written put option, so she sells it to a buyer for a premium. Alice is now earning x% from the cDAI and got y% from the put premium, of course, with the caveat that she must buy ETH at 300 DAI at any point before expiration. 

The buyer of the put option, Bob, can sell 1 ETH for 300 DAI to the put option contract at any point before expiration (aka exercising the put option). The put option that Bob bought is an ERC20 token, with all of its implied functionality.

After expiration, Alice claims her assets back from the options contract. She either gets DAI, ETH, or a mix of the two depending on buyers exercise behavior.

## Factory Contract

#### The factory contract is used to originate option contracts for a specific token (just ETH right now). 

Each options contract created by the factory is listed by its expiration timestamp and strike. The expiration timestamp maps to a map of strikes and their respective option contract addresses. This is purposely designed to be similar to clicking on an expiration and seeing the listed strikes for a given stock which traders should be used to. 
```solidity
mapping(uint256 => mapping(uint256 => address)) private _call_option_contracts;
mapping(uint256 => mapping(uint256 => address)) private _put_option_contracts;

function callOptionContract(uint256 expiration_timestamp, uint256 strike) 
  public 
  view 
  returns (address) 
{
  return _call_option_contracts[expiration_timestamp][strike];
}
    
function putOptionContract(uint256 expiration_timestamp, uint256 strike) 
  public 
  view 
  returns (address) 
{
  return _put_option_contracts[expiration_timestamp][strike];
}
```

### Creating an Option Contract

To create an option contract simply call the respective function in the Factory contract and specify the expiration timestamp and strike price (always in DAI). On success, the option will be listed in the Factory's respective map.
```solidity
function createCallOptionContract(uint256 expiration_timestamp, uint256 strike) 
  public 
  returns (bool success);
  
function createPutOptionContract(uint256 expiration_timestamp, uint256 strike) 
  public 
  returns (bool success);
```

And that's all there is to the factory contract!

## Option Contracts

#### The option contract controls the writing, exercise, and ERC20 functionality of each option created by the factory. 

There are two types of option contracts: one for a call, and one for a put. Their interface is almost exactly the same, however, the logic is specific to the type of contract (an exercise of a put is obvously different from that of a call). 

### Writing an Option

When you write an option, option tokens are created on a one-to-one basis the amount that you supply. You can then sell these option tokens on a DEX for a premium, and the buyer now has the right to exercise against your contributed collateral.

First find the correct address for the contract type, expiration timestamp, and strike you want from the factory contract. For both a call and put option you will call the writeOption function, however, there are different parameters depending on the type.

#### Calls 
For a call contract, you will simply send along the amount of ETH (in wei) you want to write the option for.
```solidity
function writeOption() public payable beforeExpiration returns (bool success);
```
Because these are CETH options, the collateral is exchanged for cETH from Compound. This will be a common theme throughout function implementations that you can see in the source code.

#### Puts
For a put contract, you pass the amount of ETH (in wei) you want to write for. But first you must approve the contract to be able to transfer (amount * strike) from your DAI balance. Since writing a put means you have the obligation to buy ETH at the strike, the collateral is in DAI here, not ETH. 
```solidity
function writeOption(uint256 amount) public beforeExpiration returns (bool success);
```

### Selling/Transfering Option Rights

As mentioned earlier, after writing an option you will have option tokens that are on a one-to-one basis with the ETH amount written. This is to make it easy for everyone to keep track of their balance. Please keep in mind when interacting with the contract that ETH is denominated in wei. These option tokens are under the ERC20 standard and as such can be sold and transferred by the writers.
```solidity
contract CETHCallOption is ERC20, ERC20Detailed
contract CETHPutOption is ERC20, ERC20Detailed
```
The writers always have ownership of the collateral in the contract in proportion to the amount they supplied. Ownership of the collateral is currently untransferrable, but this could be changed in future versions.

### Exercising Option Rights

Owners of the option tokens have the right to exercise at any point before expiration.

#### Calls 
To exercise a call, pass along the exercisor (an approved entity of the option tokens can exercise on the owners behalf) and the amount of ETH (in wei) to exercise for. The exercisor must have approved the option contract to access (amount * strike) of its DAI balance. The contract will then transfer the DAI to itself and send the amount in ETH to the exercisor.
```solidity
function exerciseOption(address payable exercisor, uint256 amount) public beforeExpiration returns (bool success);
```

#### Puts
To exercise a put, pass along the exercisor (an approved entity of the option tokens can exercise on the owners behalf) and send the amount of ETH (in wei) to exercise for. The contract will then transfer the (amount * strike) in DAI to the exercisor.
```solidity
function exerciseOption(address exercisor) public payable beforeExpiration returns (bool success);
```

### Claiming Contributed Collateral

After expiration, option writers can claim their proportion of the collateral. The writer either gets DAI, ETH, or a mix of the two depending on all buyers exercise behavior. Theoretically, the options shouldn't be exercised until the last day (at least), but they can be exercised whenever before expiration. The function is the same for both call and put option contracts.

#### Calls  
```solidity
function claimContribution() public afterExpiration returns (bool success);
```

#### Puts
```solidity
function claimContribution() public afterExpiration returns (bool success);
```
