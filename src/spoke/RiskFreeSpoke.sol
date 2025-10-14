// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {AccessManagedUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/AccessManagedUpgradeable.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {RiskFreeLiquidationLogic} from 'src/spoke/libraries/RiskFreeLiquidationLogic.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpokeBase, IRiskFreeSpoke} from 'src/spoke/interfaces/IRiskFreeSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title Spoke
/// @author Aave Labs
/// @notice Handles risk configuration & borrowing strategy for reserves and user positions.
/// @dev Each reserve can be associated with a separate hub.
abstract contract RiskFreeSpoke is
  IRiskFreeSpoke,
  Multicall,
  NoncesKeyed,
  AccessManagedUpgradeable,
  EIP712
{
  using SafeCast for *;
  using WadRayMath for uint256;
  using PercentageMath for *;
  using KeyValueList for KeyValueList.List;
  using PositionStatusMap for *;
  using MathUtils for *;

  /// @inheritdoc IRiskFreeSpoke
  uint256 public constant MAX_ALLOWED_ASSET_ID = type(uint16).max;

  /// @inheritdoc IRiskFreeSpoke
  bytes32 public constant SET_USER_POSITION_MANAGER_TYPEHASH =
    // keccak256('SetUserPositionManager(address positionManager,address user,bool approve,uint256 nonce,uint256 deadline)')
    0x758d23a3c07218b7ea0b4f7f63903c4e9d5cbde72d3bcfe3e9896639025a0214;

  /// @inheritdoc IRiskFreeSpoke
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD =
    RiskFreeLiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;

  /// @inheritdoc IRiskFreeSpoke
  uint256 public constant DUST_LIQUIDATION_THRESHOLD =
    RiskFreeLiquidationLogic.DUST_LIQUIDATION_THRESHOLD;

  /// @inheritdoc IRiskFreeSpoke
  uint8 public constant ORACLE_DECIMALS = 8;

  /// @inheritdoc IRiskFreeSpoke
  address public immutable ORACLE;

  uint256 internal _reserveCount;
  mapping(address user => mapping(uint256 reserveId => UserPosition)) internal _userPositions;
  mapping(address user => ISpoke.PositionStatus) internal _positionStatus;
  mapping(uint256 reserveId => Reserve) internal _reserves;
  mapping(address positionManager => PositionManagerConfig) internal _positionManager;
  mapping(uint256 reserveId => mapping(uint16 configKey => ISpoke.DynamicReserveConfig))
    internal _dynamicConfig; // dictionary of dynamic configs per reserve
  LiquidationConfig internal _liquidationConfig;
  mapping(address hub => mapping(uint256 assetId => bool)) internal _reserveExists;

  /// @notice Modifier that checks if the caller is an approved positionManager for `onBehalfOf`.
  modifier onlyPositionManager(address onBehalfOf) {
    require(_isPositionManager({user: onBehalfOf, manager: msg.sender}), Unauthorized());
    _;
  }

  /// @dev Constructor.
  /// @param oracle_ The address of the AaveOracle contract.
  constructor(address oracle_) {
    require(IAaveOracle(oracle_).DECIMALS() == ORACLE_DECIMALS, InvalidOracleDecimals());
    ORACLE = oracle_;
  }

  function initialize(address _authority) external virtual;

  /// @inheritdoc IRiskFreeSpoke
  function updateLiquidationConfig(LiquidationConfig calldata config) external restricted {
    require(
      config.targetHealthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD &&
        config.liquidationBonusFactor <= PercentageMath.PERCENTAGE_FACTOR &&
        config.healthFactorForMaxBonus < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      InvalidLiquidationConfig()
    );
    _liquidationConfig = config;
    emit UpdateLiquidationConfig(config);
  }

  /// @inheritdoc IRiskFreeSpoke
  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    ISpoke.ReserveConfig calldata config,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint256) {
    require(hub != address(0), InvalidAddress());
    require(assetId <= MAX_ALLOWED_ASSET_ID, InvalidAssetId());
    require(!_reserveExists[hub][assetId], ReserveExists());

    _validateReserveConfig(config);
    _validateDynamicReserveConfig(dynamicConfig);
    uint256 reserveId = _reserveCount++;
    uint16 dynamicConfigKey; // 0 as first key to use

    (address underlying, uint8 decimals) = IHubBase(hub).getAssetUnderlyingAndDecimals(assetId);
    require(underlying != address(0), AssetNotListed());

    _updateReservePriceSource(reserveId, priceSource);

    _reserves[reserveId] = Reserve({
      underlying: underlying,
      hub: IHubBase(hub),
      assetId: assetId.toUint16(),
      decimals: decimals,
      dynamicConfigKey: dynamicConfigKey,
      paused: config.paused,
      frozen: config.frozen,
      borrowable: config.borrowable
    });
    _dynamicConfig[reserveId][dynamicConfigKey] = dynamicConfig;
    _reserveExists[hub][assetId] = true;

    emit AddReserve(reserveId, assetId, hub);
    emit UpdateReserveConfig(reserveId, config);
    emit AddDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicConfig);

    return reserveId;
  }

  /// @inheritdoc IRiskFreeSpoke
  function updateReserveConfig(
    uint256 reserveId,
    ISpoke.ReserveConfig calldata config
  ) external restricted {
    Reserve storage reserve = _getReserve(reserveId);
    _validateReserveConfig(config);
    reserve.paused = config.paused;
    reserve.frozen = config.frozen;
    reserve.borrowable = config.borrowable;
    emit UpdateReserveConfig(reserveId, config);
  }

  /// @inheritdoc IRiskFreeSpoke
  function updateReservePriceSource(uint256 reserveId, address priceSource) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _updateReservePriceSource(reserveId, priceSource);
  }

  /// @inheritdoc IRiskFreeSpoke
  function addDynamicReserveConfig(
    uint256 reserveId,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint16) {
    require(reserveId < _reserveCount, ReserveNotListed());
    _validateDynamicReserveConfig(dynamicConfig);
    uint16 configKey;
    // overflow is desired, we implicitly invalidate & override stale config
    unchecked {
      configKey = ++_reserves[reserveId].dynamicConfigKey;
    }
    _dynamicConfig[reserveId][configKey] = dynamicConfig;
    emit AddDynamicReserveConfig(reserveId, configKey, dynamicConfig);
    return configKey;
  }

  /// @inheritdoc IRiskFreeSpoke
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _validateUpdateDynamicReserveConfig(_dynamicConfig[reserveId][configKey], dynamicConfig);
    _dynamicConfig[reserveId][configKey] = dynamicConfig;
    emit UpdateDynamicReserveConfig(reserveId, configKey, dynamicConfig);
  }

  /// @inheritdoc IRiskFreeSpoke
  function updatePositionManager(address positionManager, bool active) external restricted {
    _positionManager[positionManager].active = active;
    emit UpdatePositionManager(positionManager, active);
  }

  /// @inheritdoc ISpokeBase
  function supply(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateSupply(reserve);

    uint256 suppliedShares = reserve.hub.add(reserve.assetId, amount, msg.sender);
    userPosition.suppliedShares += suppliedShares.toUint128();

    emit Supply(reserveId, msg.sender, onBehalfOf, suppliedShares);
  }

  /// @inheritdoc ISpokeBase
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateWithdraw(reserve);
    IHubBase hub = reserve.hub;
    uint256 assetId = reserve.assetId;

    uint256 withdrawAmount = MathUtils.min(
      amount,
      hub.previewRemoveByShares(assetId, userPosition.suppliedShares)
    );
    uint256 withdrawnShares = hub.remove(assetId, withdrawAmount, msg.sender);

    userPosition.suppliedShares -= withdrawnShares.toUint128();

    if (_positionStatus[onBehalfOf].isUsingAsCollateral(reserveId)) {
      _refreshAndValidateUserPosition(onBehalfOf);
    }

    emit Withdraw(reserveId, msg.sender, onBehalfOf, withdrawnShares);
  }

  /// @inheritdoc ISpokeBase
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    ISpoke.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    _validateBorrow(reserve);
    IHubBase hub = reserve.hub;

    uint256 drawnShares = hub.draw(reserve.assetId, amount, msg.sender);
    userPosition.drawnShares += drawnShares.toUint128();
    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

    _refreshAndValidateUserPosition(onBehalfOf);

    emit Borrow(reserveId, msg.sender, onBehalfOf, drawnShares);
  }

  /// @inheritdoc ISpokeBase
  function repay(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateRepay(reserve);
    IHubBase hub = reserve.hub;
    uint256 assetId = reserve.assetId;

    uint256 drawnDebtRestored = hub.previewRestoreByShares(assetId, userPosition.drawnShares);
    drawnDebtRestored = MathUtils.min(drawnDebtRestored, amount);

    IHubBase.PremiumDelta memory premiumDelta;
    uint256 restoredShares = hub.restore(assetId, drawnDebtRestored, 0, premiumDelta, msg.sender);

    userPosition.drawnShares -= restoredShares.toUint128();
    if (userPosition.drawnShares == 0) {
      _positionStatus[onBehalfOf].setBorrowing(reserveId, false);
    }

    emit Repay(reserveId, msg.sender, onBehalfOf, restoredShares, premiumDelta);
  }

  /// @inheritdoc ISpokeBase
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external {
    UserAccountData memory userAccountData = _calculateUserAccountData(user);
    RiskFreeLiquidationLogic.LiquidateUserParams memory params = RiskFreeLiquidationLogic
      .LiquidateUserParams({
        collateralReserveId: collateralReserveId,
        debtReserveId: debtReserveId,
        oracle: ORACLE,
        user: user,
        debtToCover: debtToCover,
        healthFactor: userAccountData.healthFactor,
        drawnDebt: 0, // populated below
        totalDebtValue: userAccountData.totalDebtValue,
        activeCollateralCount: userAccountData.activeCollateralCount,
        borrowedCount: userAccountData.borrowedCount,
        liquidator: msg.sender
      });

    (params.drawnDebt) = _reserves[debtReserveId].hub.previewRestoreByShares(
      _reserves[debtReserveId].assetId,
      _userPositions[user][debtReserveId].drawnShares
    );

    ISpoke.DynamicReserveConfig storage collateralDynConfig = _dynamicConfig[collateralReserveId][
      _userPositions[user][collateralReserveId].configKey
    ];

    bool isUserInDeficit = RiskFreeLiquidationLogic.liquidateUser(
      _reserves[collateralReserveId],
      _reserves[debtReserveId],
      _userPositions[user][collateralReserveId],
      _userPositions[user][debtReserveId],
      _positionStatus[user],
      _liquidationConfig,
      collateralDynConfig,
      params
    );

    if (isUserInDeficit) {
      _reportDeficit(user);
    }
  }

  /// @inheritdoc IRiskFreeSpoke
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    _validateSetUsingAsCollateral(_reserves[reserveId], usingAsCollateral);
    ISpoke.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];

    if (positionStatus.isUsingAsCollateral(reserveId) == usingAsCollateral) {
      return;
    }
    positionStatus.setUsingAsCollateral(reserveId, usingAsCollateral);

    if (usingAsCollateral) {
      _refreshDynamicConfig(onBehalfOf, reserveId);
    } else {
      _refreshAndValidateUserPosition(onBehalfOf);
    }

    emit SetUsingAsCollateral(reserveId, msg.sender, onBehalfOf, usingAsCollateral);
  }

  /// @inheritdoc IRiskFreeSpoke
  function updateUserRiskPremium(address onBehalfOf) external {}

  /// @inheritdoc IRiskFreeSpoke
  function updateUserDynamicConfig(address onBehalfOf) external {
    if (!_isPositionManager({user: onBehalfOf, manager: msg.sender})) {
      _checkCanCall(msg.sender, msg.data);
    }
    _refreshAndValidateUserPosition(onBehalfOf);
  }

  /// @inheritdoc IRiskFreeSpoke
  function setUserPositionManager(address positionManager, bool approve) external {
    _setUserPositionManager({positionManager: positionManager, user: msg.sender, approve: approve});
  }

  /// @inheritdoc IRiskFreeSpoke
  function setUserPositionManagerWithSig(
    address positionManager,
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          SET_USER_POSITION_MANAGER_TYPEHASH,
          positionManager,
          user,
          approve,
          nonce,
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, nonce);
    _setUserPositionManager({positionManager: positionManager, user: user, approve: approve});
  }

  /// @inheritdoc IRiskFreeSpoke
  function renouncePositionManagerRole(address onBehalfOf) external {
    if (!_positionManager[msg.sender].approval[onBehalfOf]) {
      return;
    }
    _positionManager[msg.sender].approval[onBehalfOf] = false;
    emit SetUserPositionManager(onBehalfOf, msg.sender, false);
  }

  /// @inheritdoc IRiskFreeSpoke
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external {
    Reserve storage reserve = _reserves[reserveId];
    address underlying = reserve.underlying;
    require(underlying != address(0), ReserveNotListed());
    try
      IERC20Permit(underlying).permit({
        owner: onBehalfOf,
        spender: address(reserve.hub),
        value: value,
        deadline: deadline,
        v: permitV,
        r: permitR,
        s: permitS
      })
    {} catch {}
  }

  /// @inheritdoc IRiskFreeSpoke
  function getLiquidationLogic() external pure returns (address) {
    return address(RiskFreeLiquidationLogic);
  }

  /// @inheritdoc IRiskFreeSpoke
  function getLiquidationConfig() external view returns (LiquidationConfig memory) {
    return _liquidationConfig;
  }

  /// @inheritdoc IRiskFreeSpoke
  function getReserveCount() external view returns (uint256) {
    return _reserveCount;
  }

  /// @inheritdoc ISpokeBase
  function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeAddedAssets(reserve.assetId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeAddedShares(reserve.assetId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeOwed(reserve.assetId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeTotalOwed(reserve.assetId, address(this));
  }

  /// @inheritdoc IRiskFreeSpoke
  function getReserve(uint256 reserveId) external view returns (Reserve memory) {
    return _getReserve(reserveId);
  }

  /// @inheritdoc IRiskFreeSpoke
  function getReserveConfig(uint256 reserveId) external view returns (ISpoke.ReserveConfig memory) {
    Reserve storage reserve = _getReserve(reserveId);
    return
      ISpoke.ReserveConfig({
        paused: reserve.paused,
        frozen: reserve.frozen,
        borrowable: reserve.borrowable,
        collateralRisk: 0
      });
  }

  /// @inheritdoc IRiskFreeSpoke
  function getDynamicReserveConfig(
    uint256 reserveId
  ) external view returns (ISpoke.DynamicReserveConfig memory) {
    Reserve storage reserve = _getReserve(reserveId);
    return _dynamicConfig[reserveId][reserve.dynamicConfigKey];
  }

  /// @inheritdoc IRiskFreeSpoke
  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (ISpoke.DynamicReserveConfig memory) {
    _getReserve(reserveId);
    return _dynamicConfig[reserveId][configKey];
  }

  /// @inheritdoc IRiskFreeSpoke
  function isUsingAsCollateral(uint256 reserveId, address user) external view returns (bool) {
    _getReserve(reserveId);
    return _positionStatus[user].isUsingAsCollateral(reserveId);
  }

  /// @inheritdoc IRiskFreeSpoke
  function isBorrowing(uint256 reserveId, address user) external view returns (bool) {
    _getReserve(reserveId);
    return _positionStatus[user].isBorrowing(reserveId);
  }

  /// @inheritdoc ISpokeBase
  function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return
      reserve.hub.previewRemoveByShares(
        reserve.assetId,
        _userPositions[user][reserveId].suppliedShares
      );
  }

  /// @inheritdoc ISpokeBase
  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256) {
    _getReserve(reserveId);
    return _userPositions[user][reserveId].suppliedShares;
  }

  /// @inheritdoc ISpokeBase
  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[user][reserveId];
    uint256 drawnDebt = reserve.hub.previewRestoreByShares(
      reserve.assetId,
      userPosition.drawnShares
    );
    return (drawnDebt, 0);
  }

  /// @inheritdoc ISpokeBase
  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[user][reserveId];
    uint256 drawnDebt = reserve.hub.previewRestoreByShares(
      reserve.assetId,
      userPosition.drawnShares
    );
    return drawnDebt;
  }

  /// @inheritdoc IRiskFreeSpoke
  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (UserPosition memory) {
    _getReserve(reserveId);
    return _userPositions[user][reserveId];
  }

  /// @inheritdoc IRiskFreeSpoke
  function getLiquidationBonus(
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) external view returns (uint256) {
    _getReserve(reserveId);
    return
      RiskFreeLiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: _liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: _liquidationConfig.liquidationBonusFactor,
        healthFactor: healthFactor,
        maxLiquidationBonus: _dynamicConfig[reserveId][_userPositions[user][reserveId].configKey]
          .maxLiquidationBonus
      });
  }

  /// @inheritdoc IRiskFreeSpoke
  function getUserAccountData(address user) external view returns (UserAccountData memory) {
    return _calculateUserAccountData(user);
  }

  /// @inheritdoc IRiskFreeSpoke
  function isPositionManagerActive(address positionManager) external view returns (bool) {
    return _positionManager[positionManager].active;
  }

  /// @inheritdoc IRiskFreeSpoke
  function isPositionManager(address user, address positionManager) external view returns (bool) {
    return _isPositionManager(user, positionManager);
  }

  /// @inheritdoc IRiskFreeSpoke
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  function _updateReservePriceSource(uint256 reserveId, address priceSource) internal {
    require(priceSource != address(0), InvalidAddress());
    IAaveOracle(ORACLE).setReserveSource(reserveId, priceSource);
    emit UpdateReservePriceSource(reserveId, priceSource);
  }

  function _setUserPositionManager(address positionManager, address user, bool approve) internal {
    PositionManagerConfig storage config = _positionManager[positionManager];
    // only allow approval when position manager is active for improved UX
    require(!approve || config.active, InactivePositionManager());
    config.approval[user] = approve;
    emit SetUserPositionManager(user, positionManager, approve);
  }

  /// @notice Refreshes user dynamic configuration and checks the position is healthy.
  function _refreshAndValidateUserPosition(address user) internal {
    UserAccountData memory accountData = _calculateAndRefreshUserAccountData(user);
    require(
      accountData.healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      HealthFactorBelowThreshold()
    );
  }

  /// @notice Refreshes the dynamic config and calculates the user account data.
  function _calculateAndRefreshUserAccountData(
    address user
  ) internal returns (UserAccountData memory) {
    UserAccountData memory accountData = _calculateAndPotentiallyRefreshUserAccountData(user, true);
    emit RefreshAllUserDynamicConfig(user);
    return accountData;
  }

  /// @notice Refreshes the dynamic config and calculates the user account data if `refreshConfig` is true.
  /// @dev User RiskPremium calc runs until the first of either debt or collateral is exhausted.
  function _calculateAndPotentiallyRefreshUserAccountData(
    address user,
    bool refreshConfig
  ) internal returns (UserAccountData memory accountData) {
    ISpoke.PositionStatus storage positionStatus = _positionStatus[user];

    uint256 reserveId = _reserveCount;
    bool borrowing;
    bool collateral;
    while (true) {
      (reserveId, borrowing, collateral) = positionStatus.next(reserveId);
      if (reserveId == PositionStatusMap.NOT_FOUND) break;

      UserPosition storage userPosition = _userPositions[user][reserveId];
      Reserve storage reserve = _reserves[reserveId];

      uint256 assetPrice = IAaveOracle(ORACLE).getReservePrice(reserveId);
      uint256 assetUnit = MathUtils.uncheckedExp(10, reserve.decimals);
      uint256 assetId = reserve.assetId;
      IHubBase hub = reserve.hub;

      if (collateral) {
        uint256 collateralFactor = _dynamicConfig[reserveId][
          refreshConfig
            ? (userPosition.configKey = reserve.dynamicConfigKey)
            : userPosition.configKey
        ].collateralFactor;
        if (collateralFactor > 0) {
          uint256 suppliedShares = userPosition.suppliedShares;
          if (suppliedShares > 0) {
            // cannot round down to zero
            uint256 userCollateralValue = (hub.previewRemoveByShares(assetId, suppliedShares) *
              assetPrice).wadDivDown(assetUnit);
            accountData.totalCollateralValue += userCollateralValue;
            accountData.avgCollateralFactor += collateralFactor * userCollateralValue;
            accountData.activeCollateralCount = accountData.activeCollateralCount.uncheckedAdd(1);
          }
        }
      }

      if (borrowing) {
        uint256 drawnDebt = hub.previewRestoreByShares(assetId, userPosition.drawnShares);
        accountData.totalDebtValue += (drawnDebt * assetPrice).wadDivUp(assetUnit);
        accountData.borrowedCount = accountData.borrowedCount.uncheckedAdd(1);
      }
    }

    if (accountData.totalDebtValue > 0) {
      // at this point, `avgCollateralFactor` is the collateral-weighted sum (scaled by `collateralFactor` in BPS)
      // health factor uses this directly for simplicity
      // the division by `totalCollateralValue` to compute the weighted average is done later
      accountData.healthFactor = accountData
        .avgCollateralFactor
        .wadDivDown(accountData.totalDebtValue)
        .fromBpsDown();
    } else {
      accountData.healthFactor = type(uint256).max;
    }

    if (accountData.totalCollateralValue > 0) {
      accountData.avgCollateralFactor = accountData
        .avgCollateralFactor
        .wadDivDown(accountData.totalCollateralValue)
        .fromBpsDown();
    }

    return accountData;
  }

  function _refreshDynamicConfig(address user, uint256 reserveId) internal {
    _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
    emit RefreshSingleUserDynamicConfig(user, reserveId);
  }

  /// @notice Reports deficits for all debt reserves of the user, including the reserve being repaid during liquidation.
  /// @dev Deficit validation should already have occurred during liquidation.
  function _reportDeficit(address user) internal {
    ISpoke.PositionStatus storage positionStatus = _positionStatus[user];
    uint256 reserveId = _reserveCount;

    while ((reserveId = positionStatus.nextBorrowing(reserveId)) != PositionStatusMap.NOT_FOUND) {
      UserPosition storage userPosition = _userPositions[user][reserveId];
      Reserve storage reserve = _reserves[reserveId];
      IHubBase hub = reserve.hub;
      uint256 assetId = reserve.assetId;

      uint256 drawnDebtReported = hub.previewRestoreByShares(assetId, userPosition.drawnShares);

      IHubBase.PremiumDelta memory premiumDelta;
      uint256 deficitShares = hub.reportDeficit(assetId, drawnDebtReported, 0, premiumDelta);
      userPosition.drawnShares -= deficitShares.toUint128();
      positionStatus.setBorrowing(reserveId, false);
    }
  }

  function _getReserve(uint256 reserveId) internal view returns (Reserve storage) {
    Reserve storage reserve = _reserves[reserveId];
    require(address(reserve.hub) != address(0), ReserveNotListed());
    return reserve;
  }

  function _validateReserveConfig(ISpoke.ReserveConfig calldata config) internal pure {}

  /// @dev CollateralFactor of historical config keys cannot be 0, which allows liquidations to proceed.
  function _validateUpdateDynamicReserveConfig(
    ISpoke.DynamicReserveConfig storage currentConfig,
    ISpoke.DynamicReserveConfig calldata newConfig
  ) internal view {
    // sufficient check since maxLiquidationBonus is always >= 100_00
    require(currentConfig.maxLiquidationBonus > 0, ConfigKeyUninitialized());
    require(newConfig.collateralFactor > 0, InvalidCollateralFactor());
    _validateDynamicReserveConfig(newConfig);
  }

  function _validateSupply(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
    require(!reserve.frozen, ReserveFrozen());
  }

  function _validateWithdraw(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
  }

  function _validateBorrow(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
    require(!reserve.frozen, ReserveFrozen());
    require(reserve.borrowable, ReserveNotBorrowable());
    // health factor is checked at the end of borrow action
  }

  function _validateRepay(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
  }

  function _validateSetUsingAsCollateral(
    Reserve storage reserve,
    bool usingAsCollateral
  ) internal view {
    require(address(reserve.hub) != address(0), ReserveNotListed());
    require(!reserve.paused, ReservePaused());
    // can disable as collateral if the reserve is frozen
    require(!usingAsCollateral || !reserve.frozen, ReserveFrozen());
  }

  /// @notice Returns whether `manager` is active & approved positionManager for `user`.
  function _isPositionManager(address user, address manager) internal view returns (bool) {
    if (user == manager) return true;
    PositionManagerConfig storage config = _positionManager[manager];
    return config.active && config.approval[user];
  }

  function _calculateUserAccountData(address user) internal view returns (UserAccountData memory) {
    // SAFETY: function does not modify state when refreshConfig is false.
    return _castToView(_calculateAndPotentiallyRefreshUserAccountData)(user, false);
  }

  /// @dev Enforces compatible `maxLiquidationBonus` and `collateralFactor` so at the moment debt is created
  /// there is enough collateral to cover liquidation.
  function _validateDynamicReserveConfig(
    ISpoke.DynamicReserveConfig calldata config
  ) internal pure {
    require(
      config.collateralFactor < PercentageMath.PERCENTAGE_FACTOR &&
        config.maxLiquidationBonus >= PercentageMath.PERCENTAGE_FACTOR &&
        config.maxLiquidationBonus.percentMulUp(config.collateralFactor) <
        PercentageMath.PERCENTAGE_FACTOR,
      InvalidCollateralFactorAndMaxLiquidationBonus()
    );
    require(config.liquidationFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidationFee());
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('Spoke', '1');
  }

  function _castToView(
    function(address, bool) internal returns (UserAccountData memory) fnIn
  )
    internal
    pure
    returns (function(address, bool) internal view returns (UserAccountData memory) fnOut)
  {
    assembly ('memory-safe') {
      fnOut := fnIn
    }
  }
}
