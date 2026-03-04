// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HubInvariantsSpec} from '../../hub-suite/specs/HubInvariantsSpec.t.sol';
import {SpokeInvariantsSpec} from './SpokeInvariantsSpec.t.sol';

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Aggregates hub and spoke invariant string.
abstract contract InvariantsSpec is HubInvariantsSpec, SpokeInvariantsSpec {}
