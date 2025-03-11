library;

use ::structs::*;
use std::vec::Vec;

pub struct AddLiquidityEvent {
    pub sender: Identity,
    pub amounts: Vec<u256>,
    pub fees: Vec<u256>,
    pub invariant: u256,
    pub total_supply: u256
}

pub struct RemoveLiquidityEvent {
    pub sender: Identity,
    pub amounts: Vec<u256>,
    pub fees: Vec<u256>,
    pub total_supply: u256
}

pub struct RemoveLiquidityImbalanceEvent {
    pub sender: Identity,
    pub amounts: Vec<u256>,
    pub fees: Vec<u256>,
    pub invariant: u256,
    pub total_supply: u256
}

pub struct RemoveLiquidityOneEvent {
    pub sender: Identity,
    pub burn_amount: u256,
    pub asset_amount: u256
}

pub struct DepositEvent {
    pub sender: Identity,
    pub amount: u256,
    pub asset: AssetId
}

pub struct WithdrawEvent {
    pub sender: Identity,
    pub amounts: Vec<u256>,
    pub assets: Vec<AssetId>
}

pub struct SwapEvent {
    pub buyer: Identity,
    pub sold_id: u256,
    pub asset_sold: u256,
    pub bought_id: u256,
    pub asset_bought: u256
}

pub struct RampAEvent {
    pub old_A: u256,
    pub new_A: u256,
    pub initial_time: u256,
    pub future_time: u256
}

pub struct StopRampAEvent {
    pub A: u256,
    pub time: u256
}