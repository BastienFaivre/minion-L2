# minion-L2

## Branch eth-poa

### Problems

- `op-proposer` cannot poll L1 blocks without the tag `--allow-non-finalized`
- `op-node` cannot poll L1 blocks (experienced when trying to bridge ETH from L1 to L2)

These problems are due to the fact that the L1 is a pre-merge chain and it does not support the concepts of *finalized*/*safe* blocks.
