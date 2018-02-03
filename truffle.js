const HDWalletProvider = require("truffle-hdwallet-provider");
const config = require('./config.json');

module.exports = {
  networks: {
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(config.mnemonic, config.rinkebyProvider);
      },
      network_id: '4',
      gasPrice: 125000000000, // 125 gwei
    },
    mainnet: {
      provider: function() {
        return new HDWalletProvider(config.mnemonic, config.mainnetProvider);
      },
      network_id: '1',
      gas: 4508012,
      gasPrice: 4500000000, // 4.5 gwei
    },
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};
