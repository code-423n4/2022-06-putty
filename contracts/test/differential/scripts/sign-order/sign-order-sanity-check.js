const { Wallet } = require("ethers");
const { verifyTypedData } = require("ethers/lib/utils");
const { domain, types } = require("../hash-order/hash-order");
const { signOrder } = require("./sign-order");

const main = async () => {
  const babe = "0x000000000000000000000000000000000000babe";
  const bob = "0x0000000000000000000000000000000000000b0b";

  const addressList = [babe, babe];
  const numberList = [100];
  const order = {
    maker: babe,
    isCall: false,
    isLong: false,
    baseAsset: bob,
    strike: 1,
    premium: 2,
    duration: 3,
    expiration: 4,
    nonce: 5,
    whitelist: addressList,
    floorTokens: addressList,
    erc20Tokens: addressList,
    erc20Amounts: numberList,
    erc20Assets: [{ token: babe, tokenAmount: 7 }],
    erc721Assets: [{ token: babe, tokenId: 6 }],
  };

  const privateKey = "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
  const signer = new Wallet(privateKey);

  const verifyingContract = "0x0000000000000000000000000000000000000b0b";
  domain.verifyingContract = verifyingContract;
  const signature = await signOrder(order, verifyingContract, privateKey);
  const recoveredAddress = verifyTypedData(domain, types, order, signature);

  console.log("signing address: ", signer.address);
  console.log("signature: ", signature);
  console.log("recovered address: ", recoveredAddress);
};

main();
