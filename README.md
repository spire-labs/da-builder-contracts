# DA Builder Contracts

## Setup

1. CD into contracts
```
cd contracts
```

2. Install forge dependencies
```
forge install
```

3. (Optional) Create a .env file inside of `/contracts` to run the integration tests

## Overview

DA Builder is an execution aggregation service that takes type 2 transactions and type 3 blob transactions and sequences them into one big transaction to save execution costs on mainnet. To do this we need to take payment for gas and be able to sign transactions using a hot wallet on behalf of the proposer. To keep gas costs down we record payments off chain and charge the proposer on a scheduled basis.

### GasTank

This is a gas tank contract that proposers must fill with funds before using our service. Proposers should be able to fill up and withdraw their own funds. We have a 7 day closing window to allow us to finish charging proposers. Only the hot wallet can charge customers and only the hot wallet can withdrawl funds.

### Proposer Multicall

The proposer multicall is a contract that our service uses to batch multiple transactions into one transaction, it expects all accounts to have delegated to a 7702 account that supports the `IProposer` interface.

### IProposer
This is the expected interface for accounts to delegate to using 7702, we provide an example implementation for a 7702 proposer account for users to use, however if someone wants to use their own implementation they can, the only requirement is it supports the `IProposer` interface.

There are several different implementations of an example Proposer contract inside this repo:

- `Proposer`: This is a standard implementation, that fully trusts the `ProposerMulticall` contract and DA Builder to call it with the proper calldata
- `TrustlessProposer`: This is an implementation that encodes extra data into the calldata sent to the service, to enforce at runtime that no calldata was modified and what was sent to DA Builder is the same thing being executed onchain
- `OPStackProposer`: This is an implementation that trusts the `ProposerMulticall` and is intended for the sole purpose of posting blobs so an OP-stack chain can still derive the correct data, this is intended to be used in pair with some derivation changes in the OP-stack