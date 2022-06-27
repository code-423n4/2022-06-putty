const ethers = require("ethers");
const { _TypedDataEncoder } = require("ethers/lib/utils");

const domain = {
  name: "Putty",
  version: "2.0",
  chainId: 31337,
  verifyingContract: "0xtest",
};

// The named list of all type definitions
const types = {
  Order: [
    { name: "maker", type: "address" },
    { name: "isCall", type: "bool" },
    { name: "isLong", type: "bool" },
    { name: "baseAsset", type: "address" },
    { name: "strike", type: "uint256" },
    { name: "premium", type: "uint256" },
    { name: "duration", type: "uint256" },
    { name: "expiration", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "whitelist", type: "address[]" },
    { name: "floorTokens", type: "address[]" },
    { name: "erc20Assets", type: "ERC20Asset[]" },
    { name: "erc721Assets", type: "ERC721Asset[]" },
  ],
  ERC20Asset: [
    { name: "token", type: "address" },
    { name: "tokenAmount", type: "uint256" },
  ],
  ERC721Asset: [
    { name: "token", type: "address" },
    { name: "tokenId", type: "uint256" },
  ],
};

const hashOrder = (order, verifyingContract) => {
  domain.verifyingContract = verifyingContract;

  const hash = _TypedDataEncoder.hash(domain, types, order);
  return hash;
};

module.exports = {
  hashOrder,
  domain,
  types,
};
