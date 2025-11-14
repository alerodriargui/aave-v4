
import sys
import os
import json
import time
from dotenv import load_dotenv, find_dotenv
from web3 import Web3, HTTPProvider

# ------------------------- Setup ----------------------------

load_dotenv(find_dotenv('.env'))

NETWORK_URI = os.environ.get('DEVNET_URL')
w3 = Web3(HTTPProvider(NETWORK_URI,request_kwargs={'timeout':60}))

with open(os.path.dirname(os.path.realpath(__file__)) + "/DevnetConfig.json") as f:
  DEVNET_CONFIG = json.load(f)

# --------------------------- ABIs ---------------------------
with open(os.path.dirname(os.path.realpath(__file__)) + "/../../out/Spoke.sol/Spoke.json") as f:
  SPOKE_ABI = json.load(f)['abi']

with open(os.path.dirname(os.path.realpath(__file__)) + "/../../out/Hub.sol/Hub.json") as f:
  HUB_ABI = json.load(f)['abi']

with open(os.path.dirname(os.path.realpath(__file__)) + "/../../out/AssetInterestRateStrategy.sol/AssetInterestRateStrategy.json") as f:
  ASSET_INTEREST_RATE_STRATEGY_ABI = json.load(f)['abi']

with open(os.path.dirname(os.path.realpath(__file__)) + "/../../out/AaveOracle.sol/AaveOracle.json") as f:
  AAVE_ORACLE_ABI = json.load(f)['abi']

# ----------------------- Data Classes -----------------------
class AssetConfig:
  def __init__(self, callData):
    self.feeReceiver = callData[0]
    self.liquidityFee = callData[1]
    self.irStrategy = callData[2]
    self.reinvestmentController = callData[3]

  def print(self, asset_id):
    print("  treasury ".ljust(40, " "), self.feeReceiver)
    print("  liquidityFee ".ljust(40, " "), self.liquidityFee)
    print("  reinvestmentController ".ljust(40, " "), self.reinvestmentController)
    print("  irStrategy ".ljust(40, " "), self.irStrategy)
    ir_strategy = w3.eth.contract(abi=ASSET_INTEREST_RATE_STRATEGY_ABI, address=self.irStrategy)
    ir_strategy_config = IRStratConfig(ir_strategy.functions.getInterestRateData(asset_id).call())
    ir_strategy_config.print()

class IRStratConfig:
  def __init__(self, callData):
    self.optimalUsageRatio = callData[0]
    self.baseVariableBorrowRate = callData[1]
    self.variableRateSlope1 = callData[2]
    self.variableRateSlope2 = callData[3]

  def print(self):
    print("  irStrategy.optimalUsageRatio ".ljust(40, " "), self.optimalUsageRatio)
    print("  irStrategy.baseVariableBorrowRate ".ljust(40, " "), self.baseVariableBorrowRate)
    print("  irStrategy.variableRateSlope1 ".ljust(40, " "), self.variableRateSlope1)
    print("  irStrategy.variableRateSlope2 ".ljust(40, " "), self.variableRateSlope2)

class SpokeConfig:
  def __init__(self, callData):
    self.addCap = callData[0]
    self.drawCap = callData[1]
    self.riskPremiumThreshold = callData[2]
    self.active = callData[3]
    self.paused = callData[4]

  def print(self):
    print("  addCap ".ljust(40, " "), self.addCap)
    print("  drawCap ".ljust(40, " "), self.drawCap)
    print("  active ".ljust(40, " "), self.active)
    print("  paused ".ljust(40, " "), self.paused)

class ReserveConfig:
  def __init__(self, callData):
    self.underlying = callData[0]
    self.hub = callData[1]
    self.assetId = callData[2]
    self.decimals = callData[3]
    self.dynamicConfigKey = callData[4]
    self.paused = callData[5]
    self.frozen = callData[6]
    self.borrowable = callData[7]
    self.collateralRisk = callData[8]

  def print(self, reserve_id):
    print("  hub ".ljust(40, " "), hub_address_to_label.get(self.hub))
    print("  token ".ljust(40, " "), token_address_to_label.get(self.underlying))
    print("  reserveId ".ljust(40, " "), reserve_id)
    print("  assetId ".ljust(40, " "), self.assetId)
    print("  frozen ".ljust(40, " "), self.frozen)
    print("  paused ".ljust(40, " "), self.paused)
    print("  borrowable ".ljust(40, " "), self.borrowable)
    print("  collateralRisk ".ljust(40, " "), self.collateralRisk)

class DynamicReserveConfig:
  def __init__(self, callData):
    self.collateralFactor = callData[0]
    self.maxLiquidationBonus = callData[1]
    self.liquidationFee = callData[2]

  def print(self):
    print("  maxLiquidationBonus ".ljust(40, " "), self.maxLiquidationBonus)
    print("  liquidationFee ".ljust(40, " "), self.liquidationFee)
    print("  collateralFactor ".ljust(40, " "), self.collateralFactor)

# ----------------------- Label dicts -----------------------
token_address_to_label = {}
token_label_to_address = {}

hub_address_to_label = {}
hub_label_to_address = {}

spoke_address_to_label = {}
spoke_label_to_address = {}

# ---------------------- Display methods ----------------------
def fetch_and_print_asset_config(hub_contract, asset_id):
    print("\n")
    asset_config = AssetConfig(hub_contract.functions.getAssetConfig(asset_id).call())
    underlying_and_decimals = hub_contract.functions.getAssetUnderlyingAndDecimals(asset_id).call()
    token_label = token_address_to_label.get(underlying_and_decimals[0])
    print("  token ".ljust(40, " "), token_label)
    print("  assetId ".ljust(40, " "), asset_id)
    asset_config.print(asset_id)

def fetch_and_print_spoke_config(hub_contract, asset_id, spoke_address):
    print("\n")
    spoke_config = SpokeConfig(hub_contract.functions.getSpokeConfig(asset_id, spoke_address).call())
    print("  spoke ".ljust(40, " "), spoke_address_to_label.get(spoke_address))
    spoke_config.print()

def fetch_and_print_reserve_config(spoke_contract, oracle_contract, reserve_id):
    print("\n")
    reserve_config = ReserveConfig(spoke_contract.functions.getReserve(reserve_id).call())
    dyn_reserve_config = DynamicReserveConfig(spoke_contract.functions.getDynamicReserveConfig(reserve_id).call())
    reserve_config.print(reserve_id)
    dyn_reserve_config.print()
    print("  price feed ".ljust(40, " "), oracle_contract.functions.getReserveSource(reserve_id).call())
    print("  price ".ljust(40, " "), oracle_contract.functions.getReservePrice(reserve_id).call())


# --------------------------- Main ---------------------------
try:
  # parse and setup label dicts
  token_list = DEVNET_CONFIG["tokens"]
  for token_label in token_list:
    token_address_to_label[token_list[token_label]] = token_label
    token_label_to_address[token_label] = token_list[token_label]

  hub_list = DEVNET_CONFIG["hubConfigs"]
  for hub in hub_list:
    hub_address_to_label[hub["address"]] = hub["label"]
    hub_label_to_address[hub["label"]] = hub["address"]

  spoke_list = DEVNET_CONFIG["spokeConfigs"]
  for spoke in spoke_list:
    spoke_address_to_label[spoke["address"]] = spoke["label"]
    spoke_label_to_address[spoke["label"]] = spoke["address"]

  print("\n")
  # iterate over hubs assets & spokes configs
  for hub in hub_list:
    print("\n\n==================== HUB:", hub["label"], "====================")
    hub_contract = w3.eth.contract(abi=HUB_ABI, address=hub["address"])
    print("\n\n--------------- Asset Configs:", "---------------")
    for asset in hub['config']['assets']:
      fetch_and_print_asset_config(hub_contract, asset['id'])
    print("\n\n--------------- Spoke Configs:", "---------------")
    for spoke in hub['config']['spokes']:
      asset_ids = spoke['assetIds']
      for asset_id in asset_ids:
        fetch_and_print_spoke_config(hub_contract, asset_id, spoke_label_to_address.get(spoke['label']))

  # iterate over spokes reserves configs
  for spoke in spoke_list:
    print("\n\n==================== SPOKE:", spoke["label"], "====================")
    spoke_contract = w3.eth.contract(abi=SPOKE_ABI, address=spoke["address"])
    oracle_address = spoke_contract.functions.ORACLE().call()
    oracle_contract = w3.eth.contract(abi=AAVE_ORACLE_ABI, address=oracle_address)
    print("\n\n--------------- Reserve Configs:", "---------------")
    for reserve in spoke['reserves']:
      fetch_and_print_reserve_config(spoke_contract, oracle_contract, reserve['reserveId'])

except KeyboardInterrupt:
  exit(0)