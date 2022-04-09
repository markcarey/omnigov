# Omnichain Governance

Omnichain Governance is a means of doing on-chain proposals and voting on one chain and on-chain execution of those proposals on _other_ chains.

## Two Key Use Cases

- *Protocol on a high-gas chain*. Sometimes there are good reasons to have Protocols and NFT contracts on high gas chains like Ethereum Mainnet. But this makes DAO governance expensive: proposals and votes can cost $20+, leading to lower governance participation. Ominichain Governance enables you to do governance on a a different, lower gas chain, but still execute successful proposals on the high-gas chain in a safe and trustless manner.

- *Protocols deployed to muliple chains*. DeFi protocols like Aave and Uniswap have been deployed to multiple chains, and the list may grow in the future. It usually doesn't make sense to havce multiple DAOs on each chain to govern the deployment on that chain. With Omnichain Governance, all proposals and votes happen on a single chain, but the execution of proposals happens automatcially on the desired chains.

## How it Works

The Omnichain Governance of OmniGov combines Open Zeppelin (OZ) Governance with cross-chain messaging powered by Layer Zero. Proposals and voting happen in the standard manner using the OZ governance framework, but when a proposal reaches the stage where a successful proposal is ready for execution, a secure message is sent via Layer Zero, to the desired contract on the destination chain, along with the transaction details needed to exceute the transaction.

On the destination chain, a special OmniGov `ReceiverExecutor` contract receives the message, validates it, and executes the transaction on that chain. Of course, this contract needs any permissions and/or tokens that may be required to execute the transaction. One use of a `ReceiverExecutor` is as a treasury contract for that chain, with Layer Zero messages coming from the governance chain, sending and investing funds as desired by the DAO.

## How it was Built

The governance structure of OmniGov is based on open source contracts from Open Zeppelin, including a DAO token (`ERC20` token with `ERC20Votes` extension) and an Governor contract. Starting from a vanilla OZ Governor contract, the execution function was overidden such that it can detect specially formatted proposals that target other chains, and in those cases, rather than try to excute them on the current chain, it forwards the transactions to the desired chain by sending a message via Layer Zero. Also added to the Governor contract are related Layer Zero variables and functions.

Because the resulting Governor contract adheres to Open Zeppelin standard and interface, it can be use with DAO tools such as Tally for submitting proposals and votes.

On each destination chain, a `ReceiverExecutor` contract is deployed, which implements the Layer Zero `ILayerZeroReceiver` interface. The `lzReceive()` function requires that all messages are sent from the Layer Zero Endpoint contract. Only messages from specific destinations on specific chains. For OmniGov we allow only messages from our Governor contract address on our chose governance chain. Once these have been validated, the receiver contract takes the target, value, and calldata from the DAP proposal and executes them. For example, a proposal on a Polygon-based governor might be to send 1,000 DAI to a DAO contributor on ETH Mainnet.

*Note:* While Layer Zero supports sending tokens from one chain to another -- which works well! -- this functionality is not part of this project. While OmniGov focuses on the governance piece, it would be feasible for a DAO to incorporate both Omnichain Governance _and_ cross-chain token transfers as part of its operations.





