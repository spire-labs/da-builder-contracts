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

DA Builder is a data availability blob aggregation service that takes type 3 blob transactions from L2 rollups and aggreagtes them with other roll up transactions and posts them on behalf of rollup proposers. To do this we need to take payment for gas and be able to sign transactions using a hot wallet on behalf of the proposer. To keep gas costs down we record payments off chain and charge the proposer on a scheduled basis.


### Blob Account Manager

Essentially this is a gas tank contract that proposers must fill with funds before using our service. Proposers should be able to fill up and withdraw their own funds. We have a 7 day closing window to allow us to finish charging proposers. Only the hot wallet can charge customers and only the hot wallet can withdrawl funds.


### Proposer Multicall

The proposer must degate to our multicall using 7702 to enable us to sign transactions on their behalf. We batch up inbox contract calls into a single transaction.