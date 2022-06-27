const { Wallet } = require("ethers");
const { hashOrder, domain, types } = require("../hash-order/hash-order");

const signOrder = (order, verifyingContract, privateKey) => {
  domain.verifyingContract = verifyingContract;
  const signer = new Wallet(privateKey);
  const signature = signer._signTypedData(domain, types, order);

  return signature;
};

module.exports = {
  signOrder,
};
