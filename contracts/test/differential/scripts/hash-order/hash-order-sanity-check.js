const { _TypedDataEncoder, keccak256, toUtf8Bytes } = require("ethers/lib/utils");
const { hashOrder, domain, types } = require("./hash-order");

function id(text) {
  return keccak256(toUtf8Bytes(text));
}

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

  const verifyingContract = "0x0000000000000000000000000000000000000b0b";
  domain.verifyingContract = verifyingContract;
  const hashedDomain = _TypedDataEncoder.hashDomain(domain);
  const encoded = _TypedDataEncoder.encode(domain, types, order);
  const encoder = _TypedDataEncoder.from(types);

  console.log("order encoding", encoder.encode(order));
  console.log("type hash", id(encoder._types["Order"]));
  console.log("domain", hashedDomain);
  console.log("order hash", encoded);
  console.log("final hash", hashOrder(order, "0xf5a2fe45f4f1308502b1c136b9ef8af136141382"));
};

main();
