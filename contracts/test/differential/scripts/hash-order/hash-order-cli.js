const { hashOrder } = require("./hash-order");
const { defaultAbiCoder } = require("ethers/lib/utils");

const main = async () => {
  const encodedOrder = process.argv[2];
  const verifyingContract = process.argv[3];

  const [order] = defaultAbiCoder.decode(
    [
      "(address maker,bool isCall,bool isLong,address baseAsset,uint256 strike,uint256 premium,uint256 duration,uint256 expiration,uint256 nonce,address[] whitelist,address[] floorTokens,(address token,uint256 tokenAmount)[] erc20Assets,(address token,uint256 tokenId)[] erc721Assets)",
    ],
    encodedOrder
  );

  const hash = hashOrder(order, verifyingContract);

  process.stdout.write(hash);
  process.exit();
};

main();
