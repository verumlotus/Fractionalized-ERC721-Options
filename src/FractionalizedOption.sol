// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@primitive/contracts/interfaces/IPrimitiveFactory.sol";
import "@primitive/contracts/interfaces/IPrimitiveEngine.sol";
import "./interfaces/IPrimitiveCallback.sol";

/**
 * @title Fractionalized-ERC721-Options
 * @notice Options for ERC721 assets via fractionalizing into ERC20 tokens & depositing into Primitve
 * @author verumlotus 
 */
contract FractionalizedOption {
    /************************************************
     *  STORAGE
    ***********************************************/
    

    /************************************************
     *  IMMUTABLES & CONSTANTS
    ***********************************************/

    /************************************************
     *  EVENTS, ERRORS, MODIFIERS
    ***********************************************/
    modifier onlyEngine() {
        require(msg.sender == engine, "Caller must be engine");
        _;
    }

    /**
     * @notice creates a Primitive Pool with specified parameters, and optionally franctionalizes the NFT
     */
    constructor(bool _fractionalize) {

    }



    /************************************************
     *  Primitive Callbacks
    ***********************************************/
    /**
     * @notice Triggered when creating a new pool for an Engine
     * @param  delRisky  Amount of risky tokens required to initialize risky reserve
     * @param  delStable Amount of stable tokens required to initialize stable reserve
     */
    function createCallback(
        uint256 delRisky,
        uint256 delStable,
        bytes calldata // data bytes passed in, unused
    ) external onlyEngine {
        // For the callback, we simply need to transfer the desired amount of assets to the engine 
        IERC20(asset).safeTransfer(engine, delRisky);
        IERC20(stable).safeTransfer(engine, delStable);
    }

    /**
     * @notice Triggered when depositing tokens to an Engine
     * @param  delRisky  Amount of risky tokens required to deposit to risky margin balance
     * @param  delStable Amount of stable tokens required to deposit to stable margin balance
     */
    function depositCallback(
        uint256 delRisky,
        uint256 delStable,
        bytes calldata // data bytes passed in, unused
    ) external onlyEngine {
        if (delRisky != 0) {
            IERC20(asset).safeTransfer(engine, delRisky);
        }
        if (delStable != 0) {
            IERC20(stable).safeTransfer(engine, delStable);
        }
    }

    /**
     * @notice Triggered when providing liquidity to an Engine
     * @param  delRisky  Amount of risky tokens required to provide to risky reserve
     * @param  delStable Amount of stable tokens required to provide to stable reserve
     */
    function allocateCallback(
        uint256 delRisky,
        uint256 delStable,
        bytes calldata // data bytes passed in, unused
    ) external onlyEngine {
        IERC20(asset).safeTransfer(engine, delRisky);
        IERC20(stable).safeTransfer(engine, delStable);
    }
}
