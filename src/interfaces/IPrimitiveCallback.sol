// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@primitive/interfaces/callback/IPrimitiveCreateCallback.sol";
import "@primitive/interfaces/callback/IPrimitiveDepositCallback.sol";
import "@primitive/interfaces/callback/IPrimitiveLiquidityCallback.sol";

// Utility interface so we don't have to list out all the Primitive Call back interfaces we support
interface IPrimitiveCallback is IPrimitiveCreateCallback, IPrimitiveDepositCallback, IPrimitiveLiquidityCallback {
}