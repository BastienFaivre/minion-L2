const ethers = require('ethers');
const optimismSDK = require('@eth-optimism/sdk');
const fs = require('fs');

const privateKey = process.argv[2];
if (!privateKey) {
    console.log('Usage: node index.js <privateKey> [amount of ETH] [l1Url] [l2Url]');
    process.exit(1);
}
const ethAmount = BigInt(process.argv[3] || '1');
const l1Url = process.argv[4] || 'http://localhost:8545';
const l2Url = process.argv[5] || 'http://localhost:8547';

const readAddressFromFile = (filename) => {
    try {
        return fs.readFileSync(filename, 'utf8').trim();
    } catch (err) {
        console.log(`Could not read ${filename}: ${err}`);
        process.exit(1);
    }
}

const zeroAddr = '0x'.padEnd(42, '0');

const path = 'L2/optimism/remote/bridge/';

const contracts = {
    l1: {
        StateCommitmentChain: zeroAddr,
        CanonicalTransactionChain: zeroAddr,
        BondManager: zeroAddr,
        AddressManager: readAddressFromFile(path + 'AddressManager_address'),
        L1CrossDomainMessenger: readAddressFromFile(path + 'L1CrossDomainMessengerProxy_address'),
        L1StandardBridge: readAddressFromFile(path + 'L1StandardBridgeProxy_address'),
        OptimismPortal: readAddressFromFile(path + 'OptimismPortal_address'),
        L2OutputOracle: readAddressFromFile(path + 'L2OutputOracleProxy_address'),
    }
}

const bridges = {
    Standard: {
        l1Bridge: contracts.l1.L1StandardBridge,
        l2Bridge: '0x4200000000000000000000000000000000000010',
        Adapter: optimismSDK.StandardBridgeAdapter
    },
    ETH: {
        l1Bridge: contracts.l1.L1StandardBridge,
        l2Bridge: '0x4200000000000000000000000000000000000010',
        Adapter: optimismSDK.ETHBridgeAdapter
    }
}

let crossChainMessenger;

const getSigners = async () => {
    const l1RpcProvider = new ethers.providers.JsonRpcProvider(l1Url);
    const l2RpcProvider = new ethers.providers.JsonRpcProvider(l2Url);
    const l1Wallet = new ethers.Wallet(privateKey, l1RpcProvider);
    const l2Wallet = new ethers.Wallet(privateKey, l2RpcProvider);
    return [l1Wallet, l2Wallet];
}

const setup = async () => {
    const [l1Signer, l2Signer] = await getSigners();
    crossChainMessenger = new optimismSDK.CrossChainMessenger({
        l1ChainId: 2023,
        l2ChainId: 2320,
        l1SignerOrProvider: l1Signer,
        l2SignerOrProvider: l2Signer,
        bedrock: true,
        contracts: contracts,
        bridges: bridges,
    });
}

const gwei = BigInt(1e9);
const eth = gwei * gwei;

const reportBalances = async () => {
    const l1Balance = (await crossChainMessenger.l1Signer.getBalance()).toString().slice(0, -9);
    const l2Balance = (await crossChainMessenger.l2Signer.getBalance()).toString().slice(0, -9);
    console.log(`On L1:${l1Balance} Gwei    On L2:${l2Balance} Gwei`);
}

const depositETH = async () => {
    console.log('Deposit ETH');
    await reportBalances();
    const start = new Date();
    const response = await crossChainMessenger.depositETH(ethAmount * eth);
    console.log(`Transaction hash (on L1): ${response.hash}`);
    await response.wait();
    console.log("Waiting for status to change to RELAYED");
    console.log(`Time so far ${(new Date() - start) / 1000} seconds`);
    await crossChainMessenger.waitForMessageStatus(response.hash, optimismSDK.MessageStatus.RELAYED);
    await reportBalances();
    console.log(`depositETH took ${(new Date() - start) / 1000} seconds\n\n`)
}

const main = async () => {
    await setup();
    await depositETH();
}

main().then(() => {
    console.log('Done');
    process.exit(0);
}).catch((err) => {
    console.log('Error', err);
    process.exit(1);
});
