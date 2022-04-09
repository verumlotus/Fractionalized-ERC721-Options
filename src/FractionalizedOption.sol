// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@primitive/interfaces/IPrimitiveFactory.sol";
import "@primitive/interfaces/IPrimitiveEngine.sol";
import "./interfaces/IPrimitiveCallback.sol";
import "./interfaces/IFractionalVaultFactory.sol";
import "./interfaces/IFractionalVault.sol";
import "@oz/token/ERC20/IERC20.sol";
import "@oz/token/ERC20/utils/SafeERC20.sol";
import "@oz/token/ERC721/IERC721Receiver.sol";
import "@oz/token/ERC721/IERC721.sol";

/**
 * @title Fractionalized-ERC721-Options
 * @notice Options for ERC721 assets via fractionalizing into ERC20 tokens & depositing into Primitve
 * @author verumlotus 
 */
contract FractionalizedOption {
    using SafeERC20 for IERC20;

    /************************************************
     *  STORAGE
    ***********************************************/
    

    /************************************************
     *  IMMUTABLES & CONSTANTS & STRUCTS
    ***********************************************/
    // TODO add actual addresses

    /// @notice the zero address
    address constant ZERO_ADDRESS = address(0x0);

    /// @notice address of the factory contract for Primitive Finance
    IPrimitiveFactory constant primFactory = 0x0;

    /// @notice address of the engine contract for Primitive Finance
    IPrimitiveEngine immutable engine;

    /// @notice address of the factory contract for Fractional Art
    IFractionalVaultFactory constant fractionalArtFactory = 0x0;
    
    /// @notice address of the vault contract for fractional art
    IFractionalVault immutable fractionalArtVault;

    struct FractionalParams {
        // name of ERC20 token
        string name;
        // symbol of ERC20 token
        string symbol;
        // address of nftToken
        address nftToken;
        // tokenId
        uint256 tokenId;
        // reserve price at start of fractional ownership
        uint256 listPrice;
        // fee for curator
        uint256 fee;
    }

    /************************************************
     *  EVENTS, ERRORS, MODIFIERS
    ***********************************************/
    modifier onlyEngine() {
        require(msg.sender == engine, "Caller must be engine");
        _;
    }

    /**
     * @notice creates a Primitive Pool with specified parameters, and optionally franctionalizes the NFT
     * @dev if fractionalize is set to true, user must approve this contract to control NFT
     * @param _fractionalize true if we wish to fractionalize the specified NFT via fractional.art
     * @param _fractionalParams helper parameters if we fractionalize this NFT (if not, pass in uninitialized struct)
     * @param _asset the ERC20 token representing a fraction of the NFT. Set to 0x0 if NFT has not been fractionalized yet
     * @param _stable the ERC20 token representing the stable asset
     */
    constructor(bool _fractionalize, FractionalParams _fractionalParams, address _asset, address _stable) {
        // First, fractionalize the NFT if we are requested to do so
        if (_fractionalize) {
            (string _name, string _symbol, address _token, uint256 _id, uint256 _listPrice, uint256 _fee) = _fractionalParams;
            // Transfer NFT to this contract
            IERC721(_token).safeTransferFrom(msg.sender, address(this), _id);
            IERC721(_token).approve(address(fractionalArtFactory), _id);
            // Fix supply at 10^18
            uint256 vaultId = fractionalArtFactory.mint(_name, _symbol, _token, _id, 1e36, _listPrice, _fee);

            // TODO: Transfer the tokens minted & the curator position to msg.sender
            fractionalArtVault = fractionalArtFactory.vaults(vaultId);
            IERC20(fractionalArtVault).transfer(msg.sender, 1e36);
            fractionalArtVault.updateCurator(msg.sender);
        }

        // Check if the engine for (asset, stable) has already been deployed
        if (primFactory.getEngine(_asset, _stable) == ZERO_ADDRESS) {

        }
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

    /**
     * @inheritdoc IERC721Receiver
     */
    function onERC721Received(address, address, uint256, bytes memory) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
