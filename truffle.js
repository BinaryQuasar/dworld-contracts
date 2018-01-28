const HDWalletProvider = require("truffle-hdwallet-provider");
const config = require('./config.json');

module.exports = {
  networks: {
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(config.mnemonic, config.rinkebyProvider);
      },
      network_id: '4',
      gasPrice: 2500000000, // 2.5 gwei
    },
    mainnet: {
      provider: function() {
        return new HDWalletProvider(config.mnemonic, config.mainnetProvider);
      },
      network_id: '1',
      gas: 4295748,
      gasPrice: 1500000000, // 1.5 gwei
    },
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};
