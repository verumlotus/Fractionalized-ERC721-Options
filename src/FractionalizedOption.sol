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
 * @title Fractionalized ERC721 Options
 * @notice Options for ERC721 assets via fractionalizing into ERC20 tokens & depositing into Primitve
 * @author verumlotus 
 */
contract FractionalizedOption {
    using SafeERC20 for IERC20; 
    using SafeERC20 for IFractionalVault;    

    /************************************************
     *  IMMUTABLES & CONSTANTS
    ***********************************************/

    /// @notice address of the factory contract for Primitive Finance
    IPrimitiveFactory constant primFactory = IPrimitiveFactory(0x5cA2D631a37B21E5de2BcB0CbB892D723A96b068);

    /// @notice address of the Primitive Engine for this asset/stable pair
    IPrimitiveEngine immutable engine;

    /// @notice address of the factory contract for Fractional Art
    IFractionalVaultFactory constant fractionalArtFactory = IFractionalVaultFactory(0x85Aa7f78BdB2DE8F3e0c0010d99AD5853fFcfC63);
    
    /// @notice address of the vault contract for fractional art
    /// also is address of the ERC20 token representing the fractionalized NFT (risky asset in context of RMM Pool)
    IFractionalVault immutable fractionalArtVault;

    /// @notice address of the ERC20 token representing the stable asset
    IERC20 immutable stable;

    /// @notice poolId of our specific asset/stable pair in the primitive engine
    bytes32 immutable poolId;

    /// @notice the creator of this contract, and thus the primitive pool
    address immutable owner;

    /************************************************
     *  STRUCTS
    ***********************************************/

    /// @notice parameters for fractionalizing NFT on fractional.art
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

    /// @notice parameters for creating an RMM-01 pool
    struct PrimitivePoolParams {
        // asset amount to deposit as LP in RMM Pool
        uint256 assetAmt;
        // stable amount to deposit as LP in RMM Pool
        uint256 stableAmt; 
        // Strike price of the pool to calibrate to, with the same decimals as the stable token
        uint128 strike; 
        // Implied Volatility to calibrate to as an unsigned 32-bit integer w/ precision of 1e4, 10000 = 100%
        uint32 sigma; 
        // Maturity timestamp of the pool, in seconds
        uint32 maturity;
        // Multiplied against swap in amounts to apply fee, equal to 1 - fee %, an unsigned 32-bit integer, w/ precision of 1e4, 10000 = 100%
        uint32 gamma; 
        // Risky reserve per liq. with risky decimals, = 1 - N(d1), d1 = (ln(S/K)+(r*sigma^2/2))/sigma*sqrt(tau)
        uint256 riskyPerLp;
        // Amount of liquidity to allocate to the curve, wei value with 18 decimals of precision
        uint256 delLiquidity;
    }

    /************************************************
     *  EVENTS, ERRORS, MODIFIERS
    ***********************************************/
    
    modifier onlyEngine() {
        require(msg.sender == address(engine), "Caller must be engine");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller must be owner");
        _;
    }

    /**
     * @notice Franctionalizes the NFT and creates a Primitive Pool with specified parameters
     * @dev User must approve this contract to control NFT, and the appropriate amount of stable token balance
     * @param _stable the ERC20 token representing the stable asset
     * @param _fractionalParams helper parameters if we fractionalize this NFT (if not, pass in uninitialized struct)
     * @param _primitivePoolParams helper parameters for creating the primitive engine & pool
     */
    constructor(address _stable, FractionalParams memory _fractionalParams, PrimitivePoolParams memory _primitivePoolParams) {
        owner = msg.sender;
        stable = IERC20(_stable);

        // First, fractionalize the NFT
        // Cache on stack
        address _token = _fractionalParams.nftToken;
        uint256 _tokenId = _fractionalParams.tokenId;

        // Transfer NFT to this contract
        IERC721(_token).safeTransferFrom(msg.sender, address(this), _tokenId);
        IERC721(_token).approve(address(fractionalArtFactory), _tokenId);
        uint256 vaultId = fractionalArtFactory.mint(_fractionalParams.name, _fractionalParams.symbol, _token, _tokenId, 1e36, _fractionalParams.listPrice, _fractionalParams.fee);

        fractionalArtVault = IFractionalVault(fractionalArtFactory.vaults(vaultId));
        fractionalArtVault.updateCurator(msg.sender);

        // Primitive Finance Logic
        // Create the engine
        engine = IPrimitiveEngine(primFactory.deploy(address(fractionalArtVault), address(stable)));
        (poolId, ,) = engine.create(
            _primitivePoolParams.strike,
            _primitivePoolParams.sigma, 
            _primitivePoolParams.maturity, 
            _primitivePoolParams.gamma, 
            _primitivePoolParams.riskyPerLp, 
            _primitivePoolParams.delLiquidity, 
            ""
        );

        // There's a chance there's a small number of tokens left over after engine creation
        fractionalArtVault.safeTransfer(msg.sender, fractionalArtVault.balanceOf(address(this)));
        stable.safeTransfer(msg.sender, stable.balanceOf(address(this)));
    }

    /**
     * @notice deposits liquidity on behalf of msg.sender into the correct Primitive Pool
     * @dev Users will need to withdraw straight from primitive (an EOA is fine since there is no callback on a withdraw action)
     * @param delRisky amount of risky (fractional NFT ERC20 token) to deposit
     * @param delStable amount of stable token to deposit
     */
    function depositLiquidity(
        uint256 delRisky,
        uint256 delStable
    ) external {
        fractionalArtVault.safeTransferFrom(msg.sender, address(this), delRisky);
        stable.safeTransferFrom(msg.sender, address(this), delStable);
        engine.allocate(poolId, msg.sender, delRisky, delStable, false, "");
    }

    /**
     * @notice Allows the pool creator to withdraw the initial liquidity they provided in the constructor 
     * @param delRisky amount of risky (fractional NFT ERC20 token) to withdraw
     * @param delStable amount of stable token to withdraw
     */
    function withdrawInitialLiquidity(
        uint256 delRisky,
        uint256 delStable
    ) external onlyOwner {
        // Withdraws from this contract's account & sends to msg.sender
        engine.withdraw(msg.sender, delRisky, delStable);
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
        fractionalArtVault.safeTransfer(address(engine), delRisky);
        IERC20(stable).safeTransfer(address(engine), delStable);
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
            fractionalArtVault.safeTransfer(address(engine), delRisky);
        }
        if (delStable != 0) {
            IERC20(stable).safeTransfer(address(engine), delStable);
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
        fractionalArtVault.safeTransfer(address(engine), delRisky);
        IERC20(stable).safeTransfer(address(engine), delStable);
    }

    /**
     * @notice Receiver function for ERC721 assets
     */
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
