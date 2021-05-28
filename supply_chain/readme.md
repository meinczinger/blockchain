# Development/testing/deployment
The contracts have been developed, tests have been created, the flow has been first tested with ganache, after it was deployed to rinkeby,
the contract address is https://rinkeby.etherscan.io/address/0x6ea1c8aaa4a9c5555570d9bf25490bd665042351#code. The transaction id of the
contract creation is 0x2fdd1bea4eb02543e0386143bab6c1c90c2e74363f135f2f43703a9590c67b23.

## Libraries
The libraries used are as defined in package.json. I had to use an older version of web3, with the latest I was running into issues. For solidity, I used the latest.
I had issues as well with the boilerplate code, but was able to address them. I used @truffle/hdwallet-provider in order to be able to deploy my contract
to rinkeby. truffle-assertions was needed for the tests and web3 was required to interact with the blockchain.

The truffle and node versions I used:

- Truffle v5.3.6 (core: 5.3.6)
- Node v14.16.1

# ULM diagrams:

## Activity diagram
![Activity diagram](images/activity_diagram.png)

## Sequence diagram
![Sequence diagram](images/sequence_diagram.png)

## State diagram
![State diagram](images/state_diagram.png)

## Class diagram
![Class diagram](images/class_diagram.png)
