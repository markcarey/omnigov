# Omnichain Governance

Omnichain Governance is a means of doing on-chain proposals and voting on one chain and on-chain execution of those proposals on _other_ chains.

## Two Key Use Cases

- *Protocol on a high-gas chain*. Sometimes there are good reasons to have Protocols and NFT contracts on high gas chains like Ethereum Mainnet. But this makes DAO governance expensive: proposals and votes can cost $20+, leading to lower governance participation. Ominichain Governance enables you to do governance on a a different, lower gas chain, but still execute successful proposals on the high-gas chain in a safe and trustless manner.

- *Protocols deployed to muliple chains*. DeFi protocols like Aave and Uniswap have been deployed to multiple chains, and the list may grow in the future. It usually doesn't make sense to havce multiple DAOs on each chain to govern the deployment on that chain. With Omnichain Governance, all proposals and votes happen on a single chain, but the execution of proposals happens automatcially on the desired chains.

## How it Works

The Omnichain Governance of OmniGov combines Open Zeppelin (OZ) Governance with cross-chain messaging powered by Layer Zero. Proposals and voting happen in the standard manner using the OZ governance framework, but when a proposal reaches the stage where a successful proposal is ready for execution, a secure message is sent via Layer Zero, to the desired contract on the destination chain, along with the transaction details needed to exceute the transaction.

On the destination chain, a special OmniGov `ReceiverExecutor` contract receives the message, validates it, and executes the transaction on that chain. Of course, this contract needs any permissions and/or tokens that may be required to execute the transaction. One use of a `ReceiverExecutor` is as a treasury contract for that chain, with Layer Zero messages coming from the governance chain, sending and investing funds as desired by the DAO.

## How it was Built



