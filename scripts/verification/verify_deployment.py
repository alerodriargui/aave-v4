#!/usr/bin/env python3
"""Aave V4 deployment verification script.

Reads a deployment report JSON and a config input JSON, connects to an RPC
endpoint, and verifies that all on-chain state matches the expected configuration.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any, Optional

from web3 import Web3

# ---------------------------------------------------------------------------
# ABI loading from Forge artifacts
# ---------------------------------------------------------------------------

ARTIFACTS_DIR = Path(__file__).resolve().parent.parent.parent / "out"


def load_abi(sol_file: str, contract_name: str) -> list:
    path = ARTIFACTS_DIR / sol_file / f"{contract_name}.json"
    if not path.exists():
        sys.exit(f"Artifact not found: {path}\nRun `forge build` first.")
    with open(path) as f:
        return json.load(f)["abi"]


@dataclass(frozen=True)
class ArtifactInfo:
    sol_file: str
    contract_name: str
    impl_sol_file: Optional[str] = None
    impl_contract_name: Optional[str] = None


ARTIFACT_MAP: dict[str, ArtifactInfo] = {
    "AccessManager": ArtifactInfo("AccessManagerEnumerable.sol", "AccessManagerEnumerable"),
    "HubConfigurator": ArtifactInfo("HubConfigurator.sol", "HubConfigurator"),
    "SpokeConfigurator": ArtifactInfo("SpokeConfigurator.sol", "SpokeConfigurator"),
    "TreasurySpoke": ArtifactInfo(
        "TransparentUpgradeableProxy.sol", "TransparentUpgradeableProxy",
        impl_sol_file="TreasurySpokeInstance.sol",
        impl_contract_name="TreasurySpokeInstance",
    ),
    "Hub": ArtifactInfo("Hub.sol", "Hub"),
    "InterestRateStrategy": ArtifactInfo(
        "AssetInterestRateStrategy.sol", "AssetInterestRateStrategy",
    ),
    "Spoke": ArtifactInfo(
        "TransparentUpgradeableProxy.sol", "TransparentUpgradeableProxy",
        impl_sol_file="SpokeInstance.sol",
        impl_contract_name="SpokeInstance",
    ),
    "AaveOracle": ArtifactInfo("AaveOracle.sol", "AaveOracle"),
    "SignatureGateway": ArtifactInfo("SignatureGateway.sol", "SignatureGateway"),
    "NativeTokenGateway": ArtifactInfo("NativeTokenGateway.sol", "NativeTokenGateway"),
    "GiverPositionManager": ArtifactInfo("GiverPositionManager.sol", "GiverPositionManager"),
    "TakerPositionManager": ArtifactInfo("TakerPositionManager.sol", "TakerPositionManager"),
    "ConfigPositionManager": ArtifactInfo("ConfigPositionManager.sol", "ConfigPositionManager"),
}


@lru_cache(maxsize=None)
def load_deployed_bytecode(
    sol_file: str, contract_name: str
) -> tuple[bytes, dict, list[dict]]:
    """Return (bytecode, immutable_refs, link_refs).

    - immutable_refs: positions of constructor-set immutables (must be masked)
    - link_refs: positions of library address placeholders (will be patched)
    """
    path = ARTIFACTS_DIR / sol_file / f"{contract_name}.json"
    if not path.exists():
        sys.exit(f"Artifact not found: {path}\nRun `forge build` first.")
    with open(path) as f:
        artifact = json.load(f)
    deployed = artifact["deployedBytecode"]
    bytecode_hex = deployed["object"]
    if bytecode_hex.startswith("0x"):
        bytecode_hex = bytecode_hex[2:]

    # Replace unlinked library placeholders (__$<hash>$__) with zero bytes
    # so bytes.fromhex() can parse the string; the positions will be
    # overwritten with real addresses before comparison.
    bytecode_hex = re.sub(r"__\$[0-9a-fA-F]+\$__", "0" * 40, bytecode_hex)

    immutable_refs: dict[str, list[dict]] = {}
    for key, ranges in deployed.get("immutableReferences", {}).items():
        immutable_refs[key] = ranges

    link_refs: list[dict] = []
    for file_refs in deployed.get("linkReferences", {}).values():
        for _lib_name, ranges in file_refs.items():
            link_refs.extend(ranges)

    return bytes.fromhex(bytecode_hex), immutable_refs, link_refs


def link_artifact_bytecode(
    artifact_bytes: bytearray,
    onchain_bytes: bytes,
    link_refs: list[dict],
) -> bytearray:
    """Patch library placeholders in *artifact_bytes* with the real addresses
    extracted from *onchain_bytes*, so comparison can be a full 100% match."""
    if not link_refs:
        return artifact_bytes

    # Extract the address from the first link ref position as the canonical one
    first = link_refs[0]
    address = onchain_bytes[first["start"]:first["start"] + first["length"]]

    # Sanity: every link ref position should contain the same address
    for ref in link_refs[1:]:
        chunk = onchain_bytes[ref["start"]:ref["start"] + ref["length"]]
        if chunk != address:
            raise ValueError(
                f"Library address mismatch in on-chain bytecode: "
                f"offset {first['start']} has {address.hex()}, "
                f"offset {ref['start']} has {chunk.hex()}"
            )

    for ref in link_refs:
        start = ref["start"]
        length = ref["length"]
        artifact_bytes[start:start + length] = address

    return artifact_bytes


def mask_bytecode_ranges(bytecode: bytes, refs: dict) -> bytearray:
    masked = bytearray(bytecode)
    for ranges in refs.values():
        for ref in ranges:
            start = ref["start"]
            length = ref["length"]
            for i in range(start, start + length):
                if i < len(masked):
                    masked[i] = 0
    return masked


def _first_diff_offset(a: bytes | bytearray, b: bytes | bytearray) -> int:
    for i in range(min(len(a), len(b))):
        if a[i] != b[i]:
            return i
    return min(len(a), len(b))

# ---------------------------------------------------------------------------
# VerificationResult
# ---------------------------------------------------------------------------

GREEN = "\033[92m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"


class VerificationResult:
    def __init__(self) -> None:
        self.passed = 0
        self.failed = 0

    def ok(self, label: str, details: str = "") -> None:
        self.passed += 1
        suffix = f" ({details})" if details else ""
        print(f"  {GREEN}OK{RESET}  {label}{suffix}")

    def error(self, label: str, expected: Any, actual: Any) -> None:
        self.failed += 1
        print(f"  {RED}ERROR{RESET}  {label}")
        print(f"         expected: {expected}")
        print(f"         actual:   {actual}")

    def section(self, title: str) -> None:
        print(f"\n{BOLD}=== {title} ==={RESET}\n")

    def summary(self) -> int:
        total = self.passed + self.failed
        print(f"\n{BOLD}--- Summary ---{RESET}")
        print(f"  {GREEN}Passed:{RESET} {self.passed}/{total}")
        if self.failed:
            print(f"  {RED}Failed:{RESET} {self.failed}/{total}")
            return 1
        print("  All checks passed.")
        return 0


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------


@dataclass
class HubInfo:
    label: str
    address: str
    ir_strategy: str


@dataclass
class SpokeInfo:
    label: str
    proxy: str
    oracle: str


@dataclass
class DeployReport:
    salt: str
    access_manager: str
    hub_configurator: str
    spoke_configurator: str
    treasury_spoke: str
    hubs: list[HubInfo] = field(default_factory=list)
    spokes: list[SpokeInfo] = field(default_factory=list)
    signature_gateway: Optional[str] = None
    native_token_gateway: Optional[str] = None
    giver_position_manager: Optional[str] = None
    taker_position_manager: Optional[str] = None
    config_position_manager: Optional[str] = None

    @classmethod
    def from_json(cls, data: dict) -> "DeployReport":
        hubs: list[HubInfo] = []
        hub_addrs = data.get("hub", {})
        ir_addrs = data.get("irStrategy", {})
        for key, addr in hub_addrs.items():
            hubs.append(
                HubInfo(
                    label=key,
                    address=addr,
                    ir_strategy=ir_addrs[key],
                )
            )

        spokes: list[SpokeInfo] = []
        spoke_addrs = data.get("spoke", {})
        oracle_addrs = data.get("oracle", {})
        for key, addr in spoke_addrs.items():
            spokes.append(
                SpokeInfo(
                    label=key,
                    proxy=addr,
                    oracle=oracle_addrs[key],
                )
            )

        return cls(
            salt=data.get("salt", ""),
            access_manager=data["accessManager"],
            hub_configurator=data["hubConfigurator"],
            spoke_configurator=data["spokeConfigurator"],
            treasury_spoke=data["treasurySpoke"],
            hubs=hubs,
            spokes=spokes,
            signature_gateway=data.get("signatureGateway"),
            native_token_gateway=data.get("nativeTokenGateway"),
            giver_position_manager=data.get("giverPositionManager"),
            taker_position_manager=data.get("takerPositionManager"),
            config_position_manager=data.get("configPositionManager"),
        )

    def all_addresses(self) -> list[tuple[str, str]]:
        pairs: list[tuple[str, str]] = [
            ("AccessManager", self.access_manager),
            ("HubConfigurator", self.hub_configurator),
            ("SpokeConfigurator", self.spoke_configurator),
            ("TreasurySpoke", self.treasury_spoke),
        ]
        for h in self.hubs:
            pairs.append((f"{h.label}/Hub", h.address))
            pairs.append((f"{h.label}/InterestRateStrategy", h.ir_strategy))
        for s in self.spokes:
            pairs.append((f"{s.label}/Spoke", s.proxy))
            pairs.append((f"{s.label}/AaveOracle", s.oracle))
        for name, addr in [
            ("SignatureGateway", self.signature_gateway),
            ("NativeTokenGateway", self.native_token_gateway),
            ("GiverPositionManager", self.giver_position_manager),
            ("TakerPositionManager", self.taker_position_manager),
            ("ConfigPositionManager", self.config_position_manager),
        ]:
            if addr:
                pairs.append((name, addr))
        return pairs

    def hub_by_label(self, label: str) -> HubInfo:
        for h in self.hubs:
            if h.label == label:
                return h
        raise KeyError(f"Hub '{label}' not found in report")

    def spoke_by_label(self, label: str) -> SpokeInfo:
        for s in self.spokes:
            if s.label == label:
                return s
        raise KeyError(f"Spoke '{label}' not found in report")


class ConfigInput:
    def __init__(self, data: dict) -> None:
        self._raw = data
        self.defaults: dict = data.get("defaults", {})
        self.tokens_by_key: dict[str, dict] = data.get("tokens", {})
        self.hubs_by_key: dict[str, dict] = {
            h["key"]: h for h in data.get("hubs", [])
        }
        self.spokes_by_key: dict[str, dict] = {
            s["key"]: s for s in data.get("spokes", [])
        }
        self.assets: list[dict] = data.get("assets", [])
        self.spoke_registrations: list[dict] = data.get("spokeRegistrations", [])
        self.reserves: list[dict] = data.get("reserves", [])

    def resolve_default(
        self, entry: dict, field_name: str, defaults_section: str
    ) -> Any:
        if field_name in entry:
            return entry[field_name]
        section = self.defaults.get(defaults_section, {})
        return section[field_name]


# ---------------------------------------------------------------------------
# ContractCaller
# ---------------------------------------------------------------------------


class ContractCaller:
    def __init__(self, w3: Web3) -> None:
        self.w3 = w3
        self.hub_abi = load_abi("IHub.sol", "IHub")
        self.spoke_abi = load_abi("ISpoke.sol", "ISpoke")
        self.ir_strategy_abi = load_abi("IAssetInterestRateStrategy.sol", "IAssetInterestRateStrategy")
        self.oracle_abi = load_abi("IAaveOracle.sol", "IAaveOracle")

    ERC1967_IMPL_SLOT = int(
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", 16
    )

    def get_code(self, address: str) -> bytes:
        return self.w3.eth.get_code(Web3.to_checksum_address(address))

    def get_implementation(self, proxy_address: str) -> str:
        raw = self.w3.eth.get_storage_at(
            Web3.to_checksum_address(proxy_address), self.ERC1967_IMPL_SLOT
        )
        return Web3.to_checksum_address("0x" + raw[-20:].hex())

    def _call(self, address: str, abi: list, fn_name: str, *args: Any) -> Any:
        try:
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(address), abi=abi
            )
            return contract.functions[fn_name](*args).call()
        except Exception as e:
            print(f"  {RED}CALL FAILED{RESET} {fn_name}({', '.join(str(a) for a in args)}) on {address}: {e}")
            return None

    def call_hub(self, hub_addr: str, fn_name: str, *args: Any) -> Any:
        return self._call(hub_addr, self.hub_abi, fn_name, *args)

    def call_spoke(self, spoke_addr: str, fn_name: str, *args: Any) -> Any:
        return self._call(spoke_addr, self.spoke_abi, fn_name, *args)

    def call_ir_strategy(self, addr: str, fn_name: str, *args: Any) -> Any:
        return self._call(addr, self.ir_strategy_abi, fn_name, *args)

    def call_oracle(self, addr: str, fn_name: str, *args: Any) -> Any:
        return self._call(addr, self.oracle_abi, fn_name, *args)


# ---------------------------------------------------------------------------
# Verification functions
# ---------------------------------------------------------------------------


def _verify_single_bytecode(
    caller: ContractCaller,
    result: VerificationResult,
    label: str,
    address: str,
    sol_file: str,
    contract_name: str,
) -> None:
    expected_bytes, immutable_refs, link_refs = load_deployed_bytecode(
        sol_file, contract_name
    )
    onchain_code = caller.get_code(address)

    if not onchain_code or onchain_code in (b"", b"\x00"):
        result.error(label, "deployed bytecode", f"empty code at {address}")
        return

    if len(expected_bytes) != len(onchain_code):
        result.error(
            label,
            f"bytecode length {len(expected_bytes)}",
            f"bytecode length {len(onchain_code)} at {address}",
        )
        return

    expected = bytearray(expected_bytes)
    onchain = bytes(onchain_code)

    # Bytecode verification uses up to three steps depending on the contract:
    #
    # 1. Library linking (link_refs): the compiled artifact contains placeholder
    #    slots where external library addresses will be inserted by the linker.
    #    We read the real addresses from the on-chain bytecode at those offsets
    #    and patch them into the artifact so the two can be compared directly.
    #    Example: SpokeInstance links against deployed library contracts.
    #
    # 2. Immutable masking (immutable_refs): values set in the constructor
    #    (e.g. a proxy admin address) are baked into deployed bytecode by the
    #    compiler but are absent from the compiled artifact. Since these bytes
    #    will always differ, we zero them out on both sides before comparing.
    #    Example: proxy contracts whose admin is a constructor argument.
    #
    # 3. Direct match: contracts with no link_refs and no immutable_refs
    #    (e.g. Hub implementations) are compared byte-for-byte with no masking.
    #
    # When masking is applied the result is tagged "(masked)" to signal that
    # immutable positions were excluded — a slightly weaker guarantee than a
    # full direct match, but expected for contracts with constructor immutables.

    # Patch library placeholders with real addresses from on-chain bytecode
    if link_refs:
        expected = link_artifact_bytecode(expected, onchain, link_refs)

    # Mask immutable positions (constructor-set values differ per deployment)
    if immutable_refs:
        expected_cmp = mask_bytecode_ranges(bytes(expected), immutable_refs)
        onchain_cmp = mask_bytecode_ranges(onchain, immutable_refs)
        tag = "masked"
    else:
        expected_cmp = expected
        onchain_cmp = bytearray(onchain)
        tag = ""

    if expected_cmp == onchain_cmp:
        suffix = f"{address} ({tag})" if tag else address
        result.ok(label, suffix)
    else:
        offset = _first_diff_offset(expected_cmp, onchain_cmp)
        kind = f"matching bytecode ({tag})" if tag else "matching bytecode"
        result.error(
            label,
            kind,
            f"mismatch at byte offset {offset} at {address}",
        )


def verify_bytecode(
    caller: ContractCaller, report: DeployReport, result: VerificationResult
) -> None:
    result.section("Bytecode Verification")
    for name, addr in report.all_addresses():
        suffix = name.rsplit("/", 1)[-1]
        artifact = ARTIFACT_MAP.get(suffix)
        if artifact is None:
            result.error(name, "known artifact mapping", f"no mapping for '{suffix}'")
            continue

        _verify_single_bytecode(
            caller, result, name, addr,
            artifact.sol_file, artifact.contract_name,
        )

        if artifact.impl_sol_file:
            impl_addr = caller.get_implementation(addr)
            _verify_single_bytecode(
                caller, result, f"{name}/Implementation", impl_addr,
                artifact.impl_sol_file, artifact.impl_contract_name,
            )


def verify_hub_assets(
    caller: ContractCaller,
    report: DeployReport,
    config: ConfigInput,
    result: VerificationResult,
) -> None:
    result.section("Hub Assets & Interest Rate Configuration")
    for entry in config.assets:
        hub_key = entry["hubKey"]
        token_key = entry["tokenKey"]
        hub_info = report.hub_by_label(hub_key)
        token_addr = Web3.to_checksum_address(config.tokens_by_key[token_key]["address"])
        label = f"{hub_key}/{token_key}"

        asset_id = caller.call_hub(hub_info.address, "getAssetId", token_addr)
        if asset_id is None:
            result.error(label, "valid assetId", "call failed")
            continue

        # Interest rate data
        ir_data = caller.call_ir_strategy(
            hub_info.ir_strategy, "getInterestRateData", asset_id
        )
        if ir_data is None:
            result.error(f"{label}/IR", "interest rate data", "call failed")
        else:
            ir_input = entry["irData"]
            _check(result, f"{label}/optimalUsageRatio", ir_input["optimalUsageRatio"], ir_data[0])
            _check(result, f"{label}/baseDrawnRate", ir_input["baseDrawnRate"], ir_data[1])
            _check(result, f"{label}/rateGrowthBeforeOptimal", ir_input["rateGrowthBeforeOptimal"], ir_data[2])
            _check(result, f"{label}/rateGrowthAfterOptimal", ir_input["rateGrowthAfterOptimal"], ir_data[3])

        # Asset config — liquidityFee
        asset_cfg = caller.call_hub(hub_info.address, "getAssetConfig", asset_id)
        if asset_cfg is None:
            result.error(f"{label}/assetConfig", "asset config", "call failed")
        else:
            expected_fee = entry.get(
                "liquidityFee",
                config.defaults.get("asset", {}).get("liquidityFee", 0),
            )
            _check(result, f"{label}/liquidityFee", expected_fee, asset_cfg[1])


def verify_spoke_registrations(
    caller: ContractCaller,
    report: DeployReport,
    config: ConfigInput,
    result: VerificationResult,
) -> None:
    result.section("Spoke Registrations (Hub-side)")
    for entry in config.spoke_registrations:
        hub_key = entry["hubKey"]
        spoke_key = entry["spokeKey"]
        asset_key = entry["assetKey"]
        hub_info = report.hub_by_label(hub_key)
        spoke_info = report.spoke_by_label(spoke_key)
        token_addr = Web3.to_checksum_address(config.tokens_by_key[asset_key]["address"])
        label = f"{hub_key}/{spoke_key}/{asset_key}"

        asset_id = caller.call_hub(hub_info.address, "getAssetId", token_addr)
        if asset_id is None:
            result.error(label, "valid assetId", "call failed")
            continue

        spoke_proxy = Web3.to_checksum_address(spoke_info.proxy)
        spoke_cfg = caller.call_hub(
            hub_info.address, "getSpokeConfig", asset_id, spoke_proxy
        )
        if spoke_cfg is None:
            result.error(f"{label}/spokeConfig", "spoke config", "call failed")
            continue

        _check(result, f"{label}/addCap", entry["addCap"], spoke_cfg[0])
        _check(result, f"{label}/drawCap", entry["drawCap"], spoke_cfg[1])
        _check(
            result,
            f"{label}/riskPremiumThreshold",
            config.resolve_default(entry, "riskPremiumThreshold", "spokeRegistration"),
            spoke_cfg[2],
        )
        _check(
            result,
            f"{label}/active",
            config.resolve_default(entry, "active", "spokeRegistration"),
            spoke_cfg[3],
        )
        _check(
            result,
            f"{label}/halted",
            config.resolve_default(entry, "halted", "spokeRegistration"),
            spoke_cfg[4],
        )


def verify_reserves(
    caller: ContractCaller,
    report: DeployReport,
    config: ConfigInput,
    result: VerificationResult,
) -> None:
    result.section("Reserve Configuration (Spoke-side)")
    for entry in config.reserves:
        hub_key = entry["hubKey"]
        spoke_key = entry["spokeKey"]
        asset_key = entry["assetKey"]
        hub_info = report.hub_by_label(hub_key)
        spoke_info = report.spoke_by_label(spoke_key)
        token_addr = Web3.to_checksum_address(config.tokens_by_key[asset_key]["address"])
        label = f"{spoke_key}/{hub_key}/{asset_key}"

        asset_id = caller.call_hub(hub_info.address, "getAssetId", token_addr)
        if asset_id is None:
            result.error(label, "valid assetId", "call failed")
            continue

        hub_addr = Web3.to_checksum_address(hub_info.address)
        reserve_id = caller.call_spoke(
            spoke_info.proxy, "getReserveId", hub_addr, asset_id
        )
        if reserve_id is None:
            result.error(f"{label}/reserveId", "valid reserveId", "call failed")
            continue

        # ReserveConfig
        rcfg = caller.call_spoke(spoke_info.proxy, "getReserveConfig", reserve_id)
        if rcfg is None:
            result.error(f"{label}/reserveConfig", "reserve config", "call failed")
        else:
            _check(result, f"{label}/collateralRisk", entry["collateralRisk"], rcfg[0])
            _check(
                result,
                f"{label}/paused",
                config.resolve_default(entry, "paused", "reserve"),
                rcfg[1],
            )
            _check(
                result,
                f"{label}/frozen",
                config.resolve_default(entry, "frozen", "reserve"),
                rcfg[2],
            )
            _check(result, f"{label}/borrowable", entry["borrowable"], rcfg[3])
            _check(
                result,
                f"{label}/receiveSharesEnabled",
                config.resolve_default(entry, "receiveSharesEnabled", "reserve"),
                rcfg[4],
            )

        # Reserve struct for dynamicConfigKey
        reserve = caller.call_spoke(spoke_info.proxy, "getReserve", reserve_id)
        if reserve is None:
            result.error(f"{label}/reserve", "reserve data", "call failed")
            continue

        dynamic_config_key = reserve[6]  # dynamicConfigKey

        # DynamicReserveConfig
        drc = caller.call_spoke(
            spoke_info.proxy, "getDynamicReserveConfig", reserve_id, dynamic_config_key
        )
        if drc is None:
            result.error(f"{label}/dynamicReserveConfig", "dynamic config", "call failed")
        else:
            _check(
                result,
                f"{label}/collateralFactor",
                entry.get("collateralFactor", 0),
                drc[0],
            )
            _check(
                result,
                f"{label}/maxLiquidationBonus",
                config.resolve_default(entry, "maxLiquidationBonus", "reserve"),
                drc[1],
            )
            _check(
                result,
                f"{label}/liquidationFee",
                config.resolve_default(entry, "liquidationFee", "reserve"),
                drc[2],
            )


def verify_liquidation_configs(
    caller: ContractCaller,
    report: DeployReport,
    config: ConfigInput,
    result: VerificationResult,
) -> None:
    result.section("Liquidation Configuration")
    for spoke_entry in config.spokes_by_key.values():
        spoke_key = spoke_entry["key"]
        spoke_info = report.spoke_by_label(spoke_key)
        label = spoke_key

        liq_cfg = caller.call_spoke(spoke_info.proxy, "getLiquidationConfig")
        if liq_cfg is None:
            result.error(f"{label}/liquidationConfig", "liquidation config", "call failed")
            continue

        liq_input = spoke_entry.get("liquidationConfig", {})
        defaults_liq = config.defaults.get("spoke", {}).get("liquidationConfig", {})

        expected_thf = liq_input.get(
            "targetHealthFactor", defaults_liq.get("targetHealthFactor")
        )
        expected_hfmb = liq_input.get(
            "healthFactorForMaxBonus", defaults_liq.get("healthFactorForMaxBonus")
        )
        expected_lbf = liq_input.get(
            "liquidationBonusFactor", defaults_liq.get("liquidationBonusFactor")
        )

        _check(result, f"{label}/targetHealthFactor", expected_thf, liq_cfg[0])
        _check(result, f"{label}/healthFactorForMaxBonus", expected_hfmb, liq_cfg[1])
        _check(result, f"{label}/liquidationBonusFactor", expected_lbf, liq_cfg[2])


def verify_oracles(
    caller: ContractCaller,
    report: DeployReport,
    config: ConfigInput,
    result: VerificationResult,
) -> None:
    result.section("Oracle Configuration")
    expected_decimals = config.defaults.get("spoke", {}).get("oracleDecimals", 8)

    for spoke_info in report.spokes:
        oracle_addr = spoke_info.oracle
        label = spoke_info.label

        decimals = caller.call_oracle(oracle_addr, "decimals")
        if decimals is None:
            result.error(f"{label}/oracle/decimals", "decimals", "call failed")
        else:
            _check(result, f"{label}/oracle/decimals", expected_decimals, decimals)

        # Verify price feed sources for reserves on this spoke
        for entry in config.reserves:
            if entry["spokeKey"] != spoke_info.label:
                continue

            hub_key = entry["hubKey"]
            asset_key = entry["assetKey"]
            hub_info = report.hub_by_label(hub_key)
            token_addr = Web3.to_checksum_address(
                config.tokens_by_key[asset_key]["address"]
            )
            res_label = f"{label}/{hub_key}/{asset_key}"

            asset_id = caller.call_hub(hub_info.address, "getAssetId", token_addr)
            if asset_id is None:
                result.error(f"{res_label}/oracle/source", "valid assetId", "call failed")
                continue

            hub_addr = Web3.to_checksum_address(hub_info.address)
            reserve_id = caller.call_spoke(
                spoke_info.proxy, "getReserveId", hub_addr, asset_id
            )
            if reserve_id is None:
                result.error(f"{res_label}/oracle/source", "valid reserveId", "call failed")
                continue

            source = caller.call_oracle(oracle_addr, "getReserveSource", reserve_id)
            if source is None:
                result.error(f"{res_label}/oracle/source", "source address", "call failed")
            else:
                expected_feed = Web3.to_checksum_address(
                    config.tokens_by_key[asset_key]["priceFeed"]
                )
                _check(result, f"{res_label}/oracle/source", expected_feed, source)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _check(
    result: VerificationResult, label: str, expected: Any, actual: Any
) -> None:
    # Config JSON stores large numeric values (WAD) as strings; web3.py
    # returns them as ints.  Coerce so the comparison works.
    if isinstance(expected, str):
        try:
            expected = int(expected)
        except ValueError:
            pass
    if expected == actual:
        result.ok(label, str(actual))
    else:
        result.error(label, expected, actual)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify an Aave V4 deployment against its configuration."
    )
    parser.add_argument("--rpc-url", required=True, help="RPC endpoint URL")
    parser.add_argument(
        "--report", required=True, help="Path to deployment report JSON"
    )
    parser.add_argument("--config", required=True, help="Path to config input JSON")
    args = parser.parse_args()

    with open(args.report) as f:
        report = DeployReport.from_json(json.load(f))

    with open(args.config) as f:
        config = ConfigInput(json.load(f))

    w3 = Web3(Web3.HTTPProvider(args.rpc_url))
    if not w3.is_connected():
        print(f"{RED}ERROR{RESET}: Cannot connect to {args.rpc_url}")
        sys.exit(1)

    print(f"Connected to chain {w3.eth.chain_id}")

    caller = ContractCaller(w3)
    result = VerificationResult()

    verify_bytecode(caller, report, result)
    verify_hub_assets(caller, report, config, result)
    verify_spoke_registrations(caller, report, config, result)
    verify_reserves(caller, report, config, result)
    verify_liquidation_configs(caller, report, config, result)
    verify_oracles(caller, report, config, result)

    sys.exit(result.summary())


if __name__ == "__main__":
    main()
