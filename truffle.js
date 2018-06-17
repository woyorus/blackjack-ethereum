module.exports = {
  networks: {
    "live": {
      network_id: 1,
      host: "127.0.0.1",
      port: 8547   // Different than the default below
    }
  },
  rpc: {
    host: "127.0.0.1",
    port: 8545
  }
};
