# Fractionalized ERC721 Options

Options for ERC721 assets via fractionalizing into ERC20 tokens and depositing into Primitive's RMM-01 pool. 

This was a quick hack inspired by [0xalpharush's](https://twitter.com/0xalpharush) [tweet](https://twitter.com/0xalpharush/status/1512482898842206208) about creating options for NFTs that were constructed differently than traditional options. In short, a user deposits an NFT, the NFT is fractionalized via [fractional.art](https://fractional.art/), and the newly minted fractionalized ERC20 tokens are used to create a new pool on Primitive's RMM-01. Primitive RMM-01 is an AMM that replicates the payoff function for a covered call, you can learn more on their [docs](https://primitive.xyz/learn). 

## Why This May Be Interesting vs. Traditional Options
So, why bother with something like this at all over using a traditional options structure? Primitive's RMM-01 works well for long-tail assets where traditional options may not provide enough liquidity. In general, NFTs in particular are subject to low liquidity in the options markets. Addtionally, this is useful when the NFT is fractionalized and ownership is distributed among multiple parties. In this scenario, you can't sell a traditional option where you escrow the NFT within the option contract since no one party owns the NFT. 

## Flow for an Options Minter
- Deploy an instance of the `FractionalizedOption.sol` contract, specifiying parameters for the option such as the strike, expiry, etc. 
- At expiry, the minter can withdraw the appropriate amount of ERC20 token & stable token via the `withdrawInitialLiquidity` function. 

## Flow for holder of ERC20 token representing a fraction of an NFT
- If a user wishes to create an option out of their fraction of an NFT, they can do so via the `depositLiquidity` function. 

## Build & Testing
This repo uses Foundry for both the build and testing flows. Run `forge build` to build the repo and `forge test` for tests.

## Improvements
This is experimental & primarily built for fun. There are some caveats to this approach. Due to the nature of how Primitive works, Option minters must also deposit some amount of stablecoins alongside their fractional NFT shares. Also, unlike traditional options where the premium is paid up-front, Primitive relies on arbitrageurs and some market volatility to occur in order to generate swap fees which are meant to replicate the premium. For an illiquid asset such as an NFT, it is possible that this arbitrage won't occur and no swap fees (and thus no premium) will be generated. Additionally, estimating the implied volatility for the NFT is necessary for Primitive to accurately replicate a covered call, but there is no trivial way of estimating the volatility of an illiquid asset such as a specific NFT. 

## Disclaimer
This was created mostly for fun, and should not be used in production. It's not gas optimized and is not tested.

## Credits

[0xalpharush's](https://twitter.com/0xalpharush) [tweet](https://twitter.com/0xalpharush/status/1512482898842206208)

