// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/ILayerZeroEndpoint.sol";
import "../interfaces/ILayerZeroReceiver.sol";
import "../interfaces/ILayerZeroUserApplicationConfig.sol";

contract DAOGovernor is Initializable, GovernorUpgradeable, GovernorSettingsUpgradeable, GovernorCountingSimpleUpgradeable, GovernorVotesUpgradeable, GovernorVotesQuorumFractionUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ILayerZeroUserApplicationConfig {

    ILayerZeroEndpoint public endpoint;
    mapping(uint16 => bytes) public dstContractLookup;  // a map of the connected contracts
    bool public paused;                                 // indicates cross chain messages are paused

    event Paused(bool isPaused);
    event SendToChain(uint16 srcChainId, address toAddress, uint256 proposalId, uint64 nonce);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(ERC20VotesUpgradeable _token, address _endpoint, uint256 _votingPeriod)
        initializer public
    {
        __Governor_init("DAOGovernor");
        __GovernorSettings_init(1 /* 1 block */, _votingPeriod, 0);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4);
        //__GovernorTimelockControl_init(_timelock);
        __Ownable_init();
        __UUPSUpgradeable_init();
        endpoint = ILayerZeroEndpoint(_endpoint);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(IGovernorUpgradeable, GovernorVotesUpgradeable)
        returns (uint256)
    {
        return super.getVotes(account, blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public
        override(GovernorUpgradeable)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(GovernorUpgradeable)
    {
        if ( targets[0] == address(endpoint) ) {
            // @dev assume the remaining transactions targets are on another chain
            require(!paused, "LZ: message sending is currently paused");
            // abi.encode() the payload
            bytes memory payload = abi.encode(targets[1], values[1], calldatas[1]);

            //uint16 version = 1;
            //uint256 gasAmountForDst = 1000000;
            //bytes memory _relayerParams = abi.encodePacked(version, gasAmountForDst);

            // send LayerZero message
            endpoint.send{value: 100000000000000000}(
                uint16(values[0]),                      // destination chainId
                dstContractLookup[uint16(values[0])],   // destination UA address
                payload,                                // abi.encode()'ed bytes
                payable(address(this)),                 // refund address (LayerZero will refund any extra gas back)
                address(0x0),                           // payment address if paying in token
                bytes("")                               // adapterParameters
            );
            uint64 nonce = endpoint.getOutboundNonce(uint16(values[0]), address(this));
            emit SendToChain(uint16(values[0]), targets[1], proposalId, nonce);
        } else {
            super._execute(proposalId, targets, values, calldatas, descriptionHash);
        }
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(GovernorUpgradeable)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setDestination(uint16 _dstChainId, bytes calldata _destinationContractAddress) public onlyOwner {
        dstContractLookup[_dstChainId] = _destinationContractAddress;
    }

    function chainId() external view returns (uint16){
        return endpoint.getChainId();
    }

    //---------------------------DAO CALL----------------------------------------
    // generic config for user Application
    function setConfig(
        uint16 _version,
        uint16 _chainId,
        uint256 _configType,
        bytes calldata _config
    ) external override onlyOwner {
        endpoint.setConfig(_version, _chainId, _configType, _config);
    }

    function setSendVersion(uint16 _version) external override onlyOwner {
        endpoint.setSendVersion(_version);
    }

    function setReceiveVersion(uint16 _version) external override onlyOwner {
        endpoint.setReceiveVersion(_version);
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        endpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }

    function pauseSending(bool _pause) external onlyOwner {
        paused = _pause;
        emit Paused(_pause);
    }

}
