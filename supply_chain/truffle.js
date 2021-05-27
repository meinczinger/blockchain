const HDWalletProvider = require("@truffle/hdwallet-provider");
const infuraKey = "3d2ae8f2dc964af78daae877e7d4af08";
//
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      networkCheckTimeout: 10000,
      provider: () => new HDWalletProvider(mnemonic, `wss://rinkeby.infura.io/ws/v3/${infuraKey}`),
        network_id: 4,       // rinkeby's id
        // gas: 5500000        // rinkeby has a lower block limit than mainnet
//        gasPrice: 10000000000
    },
  }
};
