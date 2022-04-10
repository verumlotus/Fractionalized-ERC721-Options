// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@oz/token/ERC20/IERC20.sol";

interface IFractionalVault is IERC20 {
    // returns vault ID
    function mint(
        string memory _name,
        string memory _symbol,
        address _token,
        uint256 _id,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee
    ) external returns (uint256);

    function updateCurator(address _curator) external;
}
