# Minion-L2

Minion-L2 is a tool to deploy a Layer 2 system over an Ethereum Proof of Stake network.

## Specification

### Ethereum Proof of Stake network (L1)

In order to deploy a Layer 2 system, Minion-L2 starts by deploying a Ethereum Proof of Stake network. The tool deploys one L1 node per given hosts. Such nodes are made of a [Geth](https://github.com/ethereum/go-ethereum) execution client and a [Lighthouse](https://github.com/sigp/lighthouse) consensus client (beacon and validator nodes). Each nodes has the same amount of validators. The execution clients are peers of each other using enodes. The consensus clients are peers of each other using [enr](https://eips.ethereum.org/EIPS/eip-778) throught a [Lighthouse bootnode](https://github.com/sigp/lighthouse/blob/dfcb3363c757671eb19d5f8e519b4b94ac74677a/boot_node/src/cli.rs#L7).

Please refer to the usage section to see what are the customizable parameters for the L1 network.

### Layer 2 system (L2)

- [Optimism](https://optimism.io/): Minion-L2 deploys one OP node per L1 node. The deployment was based on [this tutorial](https://stack.optimism.io/docs/build/getting-started/), but with some corrections, modifications and improvements. The OP nodes are made of an [OP-Geth](https://github.com/ethereum-optimism/op-geth) execution engine and an [Optimism](https://github.com/ethereum-optimism/optimism) rollup node. The first given host will be running the unique sequencer, as well as the unique batcher (`op-batcher`) and proposer (`op-proposer`). The execution clients are not peers of each other. The rollup nodes are peers of each other using [libp2p](https://libp2p.io/).
- [Arbitrum](https://arbitrum.io/): Next planned release, not yet started.

Please refer to the usage section to see what are the customizable parameters for each L2 network.

## Installation

No installation is required. Just run the script `minion-L2.sh`.

## Usage

To see the available options, run the command:

```bash
./minion-L2.sh --help
```

### L1 custom parameters

You may want to customize the L1 network. You can check the marked _customizable_ parameters in the file [./eth-pos/constants.sh](./eth-pos/constants.sh). Also, you can modify the initial [genesis file](./eth-pos/remote/genesis.json), but DO NOT MODIFY the `config` section, and DO NOT REMOVE the already existing allocated addresses/smart contracts in the `alloc` section.

### L2 custom parameters

You may want to customize the L2 network. You can check the marked _customizable_ parameters in the file `./L2/<network>/constants.sh`.

### Advanced customizations

You can have a look directly in the `generate-configuration.sh` scripts for each network and modify the code to fit your needs. Furthermore, you can adjust the way the executables are launched (flags, options, etc...) in the `<network>.sh` scripts for each network.
