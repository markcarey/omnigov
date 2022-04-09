// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/ILayerZeroEndpoint.sol";
import "../interfaces/ILayerZeroReceiver.sol";
import "../interfaces/ILayerZeroUserApplicationConfig.sol";

contract ReceiverExecutor is Initializable, OwnableUpgradeable, ILayerZeroReceiver, ILayerZeroUserApplicationConfig {

    ILayerZeroEndpoint public endpoint;
    mapping(uint16 => bytes) public dstContractLookup;  // a map of the connected contracts

    event Paused(bool isPaused);
    event ReceiveFromChain(uint16 srcChainId, address toAddress, uint256 qty, uint64 nonce);
    event Executed(address target, uint256 value, bytes cdata);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize(address _endpoint)
        initializer public
    {
        __Ownable_init();
        endpoint = ILayerZeroEndpoint(_endpoint);
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes memory _fromAddress,
        uint64 _nonce,
        bytes memory _payload
    ) external override {
        require(msg.sender == address(endpoint)); // lzReceive must only be called by the endpoint
        require(
            _fromAddress.length == dstContractLookup[_srcChainId].length && keccak256(_fromAddress) == keccak256(dstContractLookup[_srcChainId]),
            "ReceiverExceutor: invalid source sending contract"
        );

        // decode and load the toAddress
        //(bytes memory _to, uint256 _qty) = abi.decode(_payload, (bytes, uint256));
        (address target, uint256 value, bytes memory cdata) = abi.decode(_payload, (address, uint256, bytes));

        require(target != address(0), "ReceiverExceutor: target is 0x");

        emit ReceiveFromChain(_srcChainId, target, value, _nonce);
        _execute(target, value, cdata);
        emit Executed(target, value, cdata);
    }

    function _execute(address target, uint256 value, bytes memory cdata)
        internal
    {
        string memory errorMessage = "ReceiverExceutor: call reverted without message";
        (bool success, bytes memory returndata) = target.call{value: value}(cdata);
        AddressUpgradeable.verifyCallResult(success, returndata, errorMessage);
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

}
