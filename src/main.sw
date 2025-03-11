contract;

mod structs;
mod events;

use structs::*;
use events::*;

use std::{
    asset::{
        mint,
        burn,
        mint_to,
        transfer,
    },
    contract_id::ContractId,
    auth::msg_sender,
    call_frames::msg_asset_id,
    context::{
        msg_amount,
        this_balance
    },
    hash::{Hash, sha256},
    u128::U128,
    block::timestamp,
    primitive_conversions::u64::*
};
use sway_libs::reentrancy::*;


configurable {
    FEE_DENOMINATOR: u256 = 0x00000000000000000000000000000000000000000000000000000002540be400u256,
    LENDING_PRECISION: u256 = 0x0000000000000000000000000000000000000000000000000de0b6b3a7640000u256,
    PRECISION: u256 = 0x0000000000000000000000000000000000000000000000000de0b6b3a7640000u256,
    PRECISION_MUL: (u256, u256, u256) = (
        0x000000000000000000000000000000000000000000000000000000003b9aca00u256,
        0x000000000000000000000000000000000000000000000000000000e8d4a51000u256,
        0x000000000000000000000000000000000000000000000000000000e8d4a51000u256,
    ),
    RATES: (u256, u256, u256) = (
        0x0000000000000000000000000000000000000000033b2e3c9fd0803ce8000000u256,
        0x000000000000000000000000000000000000000c9f2c9cd04674edea40000000u256,
        0x000000000000000000000000000000000000000c9f2c9cd04674edea40000000u256,
    ),
    FEE_INDEX: u256 = 0x0000000000000000000000000000000000000000000000000000000000000002u256,
    MAX_ADMIN_FEE: u256 = 0x00000000000000000000000000000000000000000000000000000002540be400u256,
    MAX_FEE: u256 = 0x000000000000000000000000000000000000000000000000000000012a05f200u256,
    MAX_A: u256 = 0x00000000000000000000000000000000000000000000000000000000000f4240u256,
    MAX_A_CHANGE: u256 = 0x000000000000000000000000000000000000000000000000000000000000000au256,
    ADMIN_ACTIONS_DELAY: u256 = 0x000000000000000000000000000000000000000000000000000000000003f480u256, // 3 * 86400
    MIN_RAMP_TIME: u256 = 0x0000000000000000000000000000000000000000000000000000000000015180u256,
    N_ASSET: u256 = 0x0000000000000000000000000000000000000000000000000000000000000003u256,
    MAX_TOTAL_SUPPLY: u256 = 0x000000000000000000000000000000000000000589ceedff47baeaf9705b981fu256, // 438790421545631456774269409311
    RATIO_PRECISION: u256 = 0x0000000000000000000000000000000000c097ce7bc90715b34b9f1000000000u256, // 1e36
    MAX_U64: u256 = 0x000000000000000000000000000000000000000000000000ffffffffffffffffu256, // max u64
}

const INDEX_0: u256 = 0x0000000000000000000000000000000000000000000000000000000000000000u256;
const INDEX_1: u256 = 0x0000000000000000000000000000000000000000000000000000000000000001u256;
const INDEX_2: u256 = 0x0000000000000000000000000000000000000000000000000000000000000002u256;

storage {
    assets: Assets = Assets::zero(),
    balances: Balances = Balances::zero(),
    fee: u256 = 0,
    admin_fee: u256 = 0,
    owner: Address = Address::zero(),
    initial_A: u256 = 0,
    future_A: u256 = 0,
    initial_A_time: u256 = 0,
    future_A_time: u256 = 0,
    is_killed: bool = false,
    initialized: bool = false,
    total_supply: u256 = 0,
    total_minted: u64 = 0,
    deposits: StorageMap<Identity, Deposited> = StorageMap {},
    user_total_deposited: StorageMap<Identity, Deposited> = StorageMap {},
    user_liquidity: StorageMap<Identity, u256> = StorageMap::<Identity, u256> {},
    self_asset_id: AssetId = AssetId::zero(),
    ass: AssetId = AssetId::zero(),
}



abi StableSwap {
    #[storage(read, write)]
    fn init(assets: Assets, a: u256, fee: u256, admin_fee: u256) -> bool;

    #[storage(read)]
    fn get_ampl() -> u256;

    #[storage(read)]
    fn get_virtual_price() -> u256;

    #[storage(read)]
    fn calc_token_amount(amounts: Vec<u256>, deposit: bool) -> (u64, u256);

    #[storage(read)]
    fn get_dy(i: u256, j: u256, dx: u256) -> u256;

    #[storage(read)]
    fn get_dy_underlying(i: u256, j: u256, dx: u256) -> u256;

    #[storage(read)]
    fn calc_withdraw_one_asset(asset_amount: u256, i: u256) -> u256;

    #[storage(read)]
    fn get_balances(i: u64) -> u256;

    #[storage(read)]
    fn get_admin_balances(i: u64) -> u256;

    #[storage(read)]
    fn get_account_balances(account: Identity, i: u64) -> u256;

    #[storage(read)]
    fn get_total_supply() -> u256;

    #[storage(read)]
    fn get_liquidity_from_u256(amount: u256) -> u64;

    #[payable, storage(read, write)]
    fn add_liquidity(amounts: Vec<u256>, min_mint_amount: u256, to: Address);

    #[payable, storage(read, write)]
    fn swap(i: u256, j: u256, dx: u256, min_dy: u256);

    #[payable, storage(read, write)]
    fn remove_liquidity(amount: u256, min_amounts: Vec<u256>);

    #[payable, storage(read, write)]
    fn remove_liquidity_imbalance(amounts: Vec<u256>, max_burn_amount: u256);

    #[payable, storage(read, write)]
    fn remove_liquidity_one_asset(asset_amount: u256, i: u256, min_amount: u256);

    #[storage(read, write)]
    fn ramp_a(future_a: u256, future_time: u256);

    #[storage(read, write)]
    fn stop_ramp_a();

    #[storage(read)]
    fn withdraw_admin_fee();

    #[payable, storage(read, write)]
    fn deposit();

    #[storage(read, write)]
    fn withdraw(amounts: Vec<u256>, assets: Vec<AssetId>);

    #[storage(read, write)]
    fn kill_me();

    #[storage(read, write)]
    fn unkill_me();

    #[storage(read)]
    fn get_assets() -> Assets;

    #[storage(read)]
    fn get_default_asset_id() -> AssetId;

    #[storage(read, write)]
    fn emergency_remove_liquidity(i: u256, amount: u64);

    #[storage(read)]
    fn get_asset_id() -> AssetId;
}


impl StableSwap for Contract {
    #[storage(read, write)]
    fn init(
        assets: Assets, 
        a: u256, 
        fee: u256, 
        admin_fee: u256
    ) -> bool {
        require(!storage.initialized.read(), "contract initalized");

        let sender = msg_sender().unwrap();
        storage.owner.write(sender.as_address().unwrap());
        storage.assets.write(assets);
        storage.initial_A.write(a);
        storage.future_A.write(a);
        storage.fee.write(fee);
        storage.admin_fee.write(admin_fee);
        storage.self_asset_id.write(AssetId::default());

        true
    }

    #[storage(read)]
    fn get_asset_id() -> AssetId {
        storage.self_asset_id.read()
    }

    #[storage(read)]
    fn get_assets() -> Assets {
        storage.assets.read()
    }


    #[storage(read)]
    fn get_default_asset_id() -> AssetId {
        AssetId::default()
    }


    #[storage(read)]
    fn get_liquidity_from_u256(amount: u256) -> u64 {
        convert_liquidity_amount_u64(amount)
    }


    #[storage(read)]
    fn get_ampl() -> u256 {
        ampl()
    }


    #[storage(read)]
    fn get_virtual_price() -> u256 {
       
        let total_supply = storage.total_supply.read();
        let d = get_d_invariant(xp(), ampl());
        d * PRECISION / total_supply
    }

    #[storage(read)]
    fn calc_token_amount(amounts: Vec<u256>, deposit: bool) -> (u64, u256) {

        let mut balances = storage.balances.read();
        let amp = ampl();
        let d0 = get_d_invariant_mem(balances, amp);

        let mut i = 0;
        
        while i < 3 {
            match deposit {
                true => {
                    match i {
                        0 => balances.balance0 = balances.balance0 + amounts.get(0).unwrap(),
                        1 => balances.balance1 = balances.balance1 + amounts.get(1).unwrap(),
                        2 => balances.balance2 = balances.balance2 + amounts.get(2).unwrap(),
                        _ => revert(0),
                    }
                },
                false => {
                    match i {
                        0 => balances.balance0 = balances.balance0 - amounts.get(0).unwrap(),
                        1 => balances.balance1 = balances.balance1 - amounts.get(1).unwrap(),
                        2 => balances.balance2 = balances.balance2 - amounts.get(2).unwrap(),
                        _ => revert(0),
                    }
                }
            }
            i += 1;
        }

        let d1 = get_d_invariant_mem(balances, amp);
        let token_amount = storage.total_supply.read();
        let mut diff: u256 = 0;

        if deposit {
            diff = d1 - d0;
        } else {
            diff = d0 - d1;
        }

        let return_liquidity = diff * token_amount / d0;
        (convert_liquidity_amount_u64(return_liquidity), return_liquidity)
    }


    #[payable, storage(read, write)]
    fn add_liquidity(amounts: Vec<u256>, min_mint_amount: u256, to: Address) {
        reentrancy_guard();
        require(!storage.is_killed.read(), "swap shut down");
        
        let sender = msg_sender().unwrap();
        let deposit = storage.deposits.get(sender).try_read().unwrap();
        let mut fees: Vec<u256> = Vec::new();
        let new_fee = storage.fee.read() * N_ASSET / (4u8.as_u256() * (N_ASSET - 1u8.as_u256()));
        let old_admin_fee = storage.admin_fee.read();

        let amp = ampl();
        let total_supply = storage.total_supply.read();
        let mut d0: u256 = 0;
        let mut old_balances = storage.balances.read();

        if total_supply > 0 {
            d0 = get_d_invariant_mem(old_balances, amp);
        }

        let mut deposit_tem = deposit;
        let mut new_balances = old_balances;
        let mut i = 0;

        while i < to_u64(N_ASSET) {
            let mut in_amount = amounts.get(i).unwrap();
            if total_supply == 0 {
                require(in_amount > 0, "initial deposit requires all coins");
            }

            match i {
                0 => {
                    require(deposit.asset0 >= in_amount, "Asset0 Insufficient Balance");
                    new_balances.balance0 = old_balances.balance0 + in_amount;
                    deposit_tem.asset0 -= in_amount;
                },
                1 => {
                    require(deposit.asset1 >= in_amount, "Asset1 Insufficient Balance");
                    new_balances.balance1 = old_balances.balance1 + in_amount;
                    deposit_tem.asset1 -= in_amount;
                },
                2 => {
                    require(deposit.asset2 >= in_amount, "Asset2 Insufficient Balance");
                    new_balances.balance2 = old_balances.balance2 + in_amount;
                    deposit_tem.asset2 -= in_amount;
                },
                _ => revert(0),
            }

            i += 1;
        }


        let d1 = get_d_invariant_mem(new_balances, amp);
        require(d1 > d0, "D inveriant error");
        
        let mut d2 = d1;
        
        if total_supply > 0 {
            let mut new_balances_tem = new_balances;
            let mut j = 0;

            while j < to_u64(N_ASSET) {
                let (ideal_balance, new_ban_tem) = match j {
                    0 => (d1 * old_balances.balance0 / d0, new_balances.balance0),
                    1 => (d1 * old_balances.balance1 / d1, new_balances.balance1),
                    2 => (d1 * old_balances.balance2 / d2, new_balances.balance2),
                    _ => revert(0),
                };
                let mut difference: u256 = 0;

                if ideal_balance > new_ban_tem {
                    difference = ideal_balance - new_ban_tem;
                } else {
                    difference = new_ban_tem - ideal_balance;
                }

                let fee_tem = new_fee * difference / FEE_DENOMINATOR;
                fees.push(fee_tem);

                if i == 0 {
                    new_balances_tem.balance0 = new_ban_tem - (fee_tem * old_admin_fee / FEE_DENOMINATOR);
                    new_balances.balance0 -= fee_tem;
                } else if i == 1 {
                    new_balances_tem.balance1 = new_ban_tem - (fee_tem * old_admin_fee / FEE_DENOMINATOR);
                    new_balances.balance1 -= fee_tem;
                } else if i == 2 {
                    new_balances_tem.balance2 = new_ban_tem - (fee_tem * old_admin_fee / FEE_DENOMINATOR);
                    new_balances.balance2 -= fee_tem;
                }

                // match i {
                //     0 => {
                //         new_balances_tem.balance0 = new_ban_tem - (fee_tem * old_admin_fee / FEE_DENOMINATOR);
                //         new_balances.balance0 -= fee_tem;
                //     },
                //     1 => {
                //         new_balances_tem.balance1 = new_ban_tem - (fee_tem * old_admin_fee / FEE_DENOMINATOR);
                //         new_balances.balance1 -= fee_tem;
                //     },
                //     2 => {
                //         new_balances_tem.balance2 = new_ban_tem - (fee_tem * old_admin_fee / FEE_DENOMINATOR);
                //         new_balances.balance2 -= fee_tem;
                //     },
                //     _ => revert(1),
                // }
                j += 1;

            }

            d2 = get_d_invariant_mem(new_balances, amp);
            storage.balances.write(new_balances_tem);

        } else {
            storage.balances.write(new_balances);
        }

        let mut mint_amount: u256 = 0;
        if total_supply == 0 {
            mint_amount = d1;
        } else {
            mint_amount = total_supply * (d2 - d0) /d0;
        }

        require(mint_amount >= min_mint_amount, "Slippage screwed you");

        let user_liqui: u256 = storage.user_liquidity.get(sender).try_read().unwrap_or(0);
        storage.user_liquidity.insert(sender, user_liqui + mint_amount);

        let new_total_supply: u256 = total_supply + mint_amount;
        require(new_total_supply <= MAX_TOTAL_SUPPLY, "Total supply limited");

        storage.total_supply.write(new_total_supply);
        storage.deposits.insert(sender, deposit_tem);

        let mut minted_amount = convert_liquidity_amount_u64(mint_amount);
        let old_total_minted = storage.total_minted.read();
        let max64 = u64::max();
        require(old_total_minted < max64, "Minted limited");
        
        if max64 - old_total_minted < minted_amount {
            storage.total_minted.write(max64);
            minted_amount = max64 - old_total_minted;
        } else {
            storage.total_minted.write(old_total_minted + minted_amount);
        }

        mint(b256::zero(), minted_amount);
        transfer(sender, AssetId::default(), minted_amount);

        log(AddLiquidityEvent {
            sender: sender,
            amounts: amounts,
            fees: fees,
            invariant: d1,
            total_supply: new_total_supply
        });

    }

    #[storage(read)]
    fn get_dy(i: u256, j: u256, dx: u256) -> u256 {
        let rates_i = match i {
            INDEX_0 => RATES.0,
            INDEX_1 => RATES.1,
            INDEX_2 => RATES.2,
            _ => revert(0),
        };
        let rates_j = match j {
            INDEX_0 => RATES.0,
            INDEX_1 => RATES.1,
            INDEX_2 => RATES.2,
            _ => revert(0),
        };
        let xp_tem = xp();
        
        let x = xp_tem.get(to_u64(i)).unwrap() + (dx * rates_i / PRECISION);
        let y = get_y(i, j, x, xp_tem);
        let dy = (xp_tem.get(to_u64(j)).unwrap() - y - 1) * PRECISION / rates_j;
        let fee_tem = storage.fee.read() * dy / FEE_DENOMINATOR;

        dy - fee_tem
    }


    #[storage(read)]
    fn get_dy_underlying(i: u256, j: u256, dx: u256) -> u256 {
        let xp_tem = xp();
        let premul_i = match i {
            INDEX_0 => PRECISION_MUL.0,
            INDEX_1 => PRECISION_MUL.1,
            INDEX_2 => PRECISION_MUL.2,
            _ => revert(0),
        };
        let premul_j = match j {
            INDEX_0 => PRECISION_MUL.0,
            INDEX_1 => PRECISION_MUL.1,
            INDEX_2 => PRECISION_MUL.2,
            _ => revert(0),
        };
        let x = xp_tem.get(to_u64(i)).unwrap() + dx * premul_i;
        let y = get_y(i, j, x, xp_tem);
        let dy = (xp_tem.get(to_u64(j)).unwrap() - y - 1) / premul_j;
        let fee_tem = storage.fee.read() * dy / FEE_DENOMINATOR;

        dy - fee_tem
    }


    #[payable, storage(read, write)]
    fn swap(i: u256, j: u256, dx: u256, min_dy: u256) {
        reentrancy_guard();
        require(!storage.is_killed.read(), "swap shut down");

        let sender = msg_sender().unwrap();
        let amount = msg_amount().as_u256();
        require(amount == dx, "Invail amount");

        let mut rates_i: u256 = 0;
        let mut rates_j: u256 = 0;
        let mut input_asset = AssetId::zero();
        let mut output_asset = AssetId::zero();

        if i == 0 {
            rates_i = RATES.0;
            input_asset = storage.assets.read().asset0;
        } else if i == 1 {
            rates_i = RATES.1;
            input_asset = storage.assets.read().asset1;
        } else if i == 2 {
            rates_i = RATES.2;
            input_asset = storage.assets.read().asset2;
        } else {
            revert(0);
        }

        if j == 0 {
            rates_j = RATES.0;
            output_asset = storage.assets.read().asset0;
        } else if j == 1 {
            rates_j = RATES.1;
            output_asset = storage.assets.read().asset1;
        } else if j == 2 {
            rates_j = RATES.2;
            output_asset = storage.assets.read().asset2;
        } else {
            revert(0);
        }

        let old_balances = storage.balances.read();
        let xp_tem = xp_mem(old_balances);

        let x = xp_tem.get(to_u64(i)).unwrap() + amount * rates_i / PRECISION;
        let y = get_y(i, j, x, xp_tem);
        let mut dy = xp_tem.get(to_u64(j)).unwrap() - y - 1;
        let dy_fee = dy * storage.fee.read() / FEE_DENOMINATOR;
        dy = (dy - dy_fee) * PRECISION / rates_j;
        require(dy >= min_dy, "Swap resulted in fewer coins than expected");

        let mut dy_admin_fee = dy_fee * storage.admin_fee.read() / FEE_DENOMINATOR;
        dy_admin_fee = dy_admin_fee * PRECISION / rates_j;

        let mut new_balances = old_balances;
        match i {
            0 => new_balances.balance0 = old_balances.balance0 + amount,
            1 => new_balances.balance1 = old_balances.balance1 + amount,
            2 => new_balances.balance2 = old_balances.balance2 + amount,
            _ => revert(0),
        }
        match j {
            0 => new_balances.balance0 = old_balances.balance0 - dy - dy_admin_fee,
            1 => new_balances.balance1 = old_balances.balance1 - dy - dy_admin_fee,
            2 => new_balances.balance2 = old_balances.balance2 - dy - dy_admin_fee,
            _ => revert(0),
        }

        storage.balances.write(new_balances);
        transfer(sender, output_asset, to_u64(dy));

        log(SwapEvent {
            buyer: sender,
            sold_id: i,
            asset_sold: dx,
            bought_id: j,
            asset_bought: dy
        });
    }


    #[payable, storage(read, write)]
    fn remove_liquidity(amount: u256, min_amounts: Vec<u256>) {
        reentrancy_guard();

        let sender = msg_sender().unwrap();
        let burn_amount = msg_amount();
        let calc_convert_amount = convert_liquidity_amount_u64(amount);
        require(calc_convert_amount == burn_amount, "invaild burn amount");

        let total_supply = storage.total_supply.read();
        let balances = storage.balances.read();
        let assets = storage.assets.read();
        let mut amounts: Vec<u256> = Vec::new();
        let mut fees: Vec<u256> = Vec::new();
        let mut i = 0;
        let mut new_balances = balances;

        while i < to_u64(N_ASSET) {
            
            let (balance_tem, asset_id) = match i {
                0 => (balances.balance0, assets.asset0),
                1 => (balances.balance1, assets.asset1),
                2 => (balances.balance2, assets.asset2),
                _ => revert(0),
            };
            
            let value = balance_tem * amount / total_supply;
            require(value >= min_amounts.get(i).unwrap(), "Withdrawal resulted in fewer coins than expected");

            match i {
                0 => new_balances.balance0 = balance_tem - value,
                1 => new_balances.balance1 = balance_tem - value,
                2 => new_balances.balance2 = balance_tem - value,
                _ => revert(0),
            }

            amounts.push(value);
            transfer(sender, asset_id, to_u64(value));
            i += 1;
        }

        storage.balances.write(new_balances);
        storage.total_supply.write(total_supply - amount);
        burn(b256::zero(), burn_amount);

        log(RemoveLiquidityEvent {
            sender: sender,
            amounts: amounts,
            fees: fees,
            total_supply: total_supply - amount
        });
    }


    #[payable, storage(read, write)]
    fn remove_liquidity_imbalance(amounts: Vec<u256>, max_burn_amount: u256) {
        reentrancy_guard();
        require(!storage.is_killed.read(), "swap shut down");

        let sender = msg_sender().unwrap();
        let total_supply = storage.total_supply.read();
        require(total_supply != 0, "zero total supply");

        let fee = storage.fee.read() * N_ASSET / (4u8.as_u256() * (N_ASSET - 1u8.as_u256()));
        let admin_fee = storage.admin_fee.read();
        let amp = ampl();

        let old_balances = storage.balances.read();
        let mut new_balances = old_balances;
        let mut push_balances = old_balances;
        let d0 = get_d_invariant_mem(old_balances, amp);
        let mut i = 0;

        while i < to_u64(N_ASSET) {
            match i {
                0 => new_balances.balance0 -= amounts.get(i).unwrap(),
                1 => new_balances.balance1 -= amounts.get(i).unwrap(),
                2 => new_balances.balance2 -= amounts.get(i).unwrap(),
                _ => revert(0),
            }
            i += 1;
        }

        let d1 = get_d_invariant_mem(new_balances, amp);
        let mut fees: Vec<u256> = Vec::new();
        i = 0;

        while i < to_u64(N_ASSET) {
            let (old_ban_tem, new_ban_tem) = match i {
                0 => (old_balances.balance0, new_balances.balance0),
                1 => (old_balances.balance1, new_balances.balance1),
                2 => (old_balances.balance2, new_balances.balance2),
                _ => revert(0),
            };
            let ideal_balance = d1 * old_ban_tem / d0;
            let mut difference: u256 = 0;

            if ideal_balance > new_ban_tem {
                difference = ideal_balance - new_ban_tem;
            } else {
                difference = new_ban_tem - ideal_balance;
            }

            fees.push(fee * difference / FEE_DENOMINATOR);
            
            match i {
                0 => {
                    let fee_tem = fees.get(i).unwrap();
                    push_balances.balance0 = new_ban_tem - (fee_tem * admin_fee / FEE_DENOMINATOR);
                    new_balances.balance0 -= fee_tem;
                },
                1 => {
                    let fee_tem = fees.get(i).unwrap();
                    push_balances.balance1 = new_ban_tem - (fee_tem * admin_fee / FEE_DENOMINATOR);
                    new_balances.balance1 -= fee_tem;
                },
                2 => {
                    let fee_tem = fees.get(i).unwrap();
                    push_balances.balance2 = new_ban_tem - (fee_tem * admin_fee / FEE_DENOMINATOR);
                    new_balances.balance2 -= fee_tem;
                },
                _ => revert(0),
            }

            i += 1;
        }

        storage.balances.write(push_balances);

        let d2 = get_d_invariant_mem(new_balances, amp);
        let mut asset_amount = (d0 - d2) * total_supply / d0;
        require(asset_amount != 0, "zero token burned");

        let mut asset_amount_u64 = convert_liquidity_amount_u64(asset_amount);
        asset_amount_u64 += 1;

        let msg_asset_amount = msg_amount();
        require(asset_amount_u64 <= msg_asset_amount, "slippage screwed you");

        burn(b256::zero(), asset_amount_u64);

        if asset_amount_u64 < msg_asset_amount {
            transfer(sender, AssetId::default(), msg_asset_amount - asset_amount_u64);
        }

        i = 0;
        let assets = storage.assets.read();
        while i < to_u64(N_ASSET) {
            let amount = amounts.get(i).unwrap();
            if amount != 0 {
                let asset_id = match i {
                    0 => assets.asset0,
                    1 => assets.asset1,
                    2 => assets.asset2,
                    _ => revert(0),
                };
                transfer(sender, asset_id, to_u64(amount));
            }
            i += 1;
        }

        storage.total_supply.write(total_supply - asset_amount);

        log(RemoveLiquidityImbalanceEvent {
            sender: sender,
            amounts: amounts,
            fees: fees,
            invariant: d1,
            total_supply: total_supply - asset_amount
        });
    }


    #[storage(read)]
    fn calc_withdraw_one_asset(asset_amount: u256, i: u256) -> u256 {
        calc_withdraw_one_asset_internal(asset_amount, i).0
    }


    #[payable, storage(read, write)]
    fn remove_liquidity_one_asset(asset_amount: u256, i: u256, min_amount: u256) {
        reentrancy_guard();
        require(!storage.is_killed.read(), "swap shut down");

        let sender = msg_sender().unwrap();
        let amount = msg_amount();
        let (mut dy, mut dy_fee) = calc_withdraw_one_asset_internal(asset_amount, i);
        let asset_amount_u64 = convert_liquidity_amount_u64(asset_amount);
        require(amount == asset_amount_u64, "Invaild burn amount");
        require(dy >= min_amount, "Not enough coins removed");

        burn(b256::zero(), asset_amount_u64);
        let mut balances = storage.balances.read();
        let mut asset = AssetId::zero();
        let assets = storage.assets.read();

        match i {
            0 => {
                balances.balance0 -= (dy + dy_fee * storage.admin_fee.read() / FEE_DENOMINATOR);
                asset = assets.asset0;
            },
            1 => {
                balances.balance1 -= (dy + dy_fee * storage.admin_fee.read() / FEE_DENOMINATOR);
                asset = assets.asset1;
            },
            2 => {
                balances.balance2 -= (dy + dy_fee * storage.admin_fee.read() / FEE_DENOMINATOR);
                asset = assets.asset2;
            },
            _ => revert(0),
        }

        storage.balances.write(balances);
        storage.total_supply.write(storage.total_supply.read() - asset_amount);
        transfer(sender, asset, to_u64(dy));

        log(RemoveLiquidityOneEvent {
            sender: sender,
            burn_amount: asset_amount,
            asset_amount: dy
        });
    }


    #[storage(read, write)]
    fn ramp_a(future_a: u256, future_time: u256) {
        only_owner(msg_sender().unwrap());
        let time_tem = (timestamp() % (2.pow(32))).as_u256();
        require(time_tem >= storage.initial_A_time.read() + MIN_RAMP_TIME, "Invaild time");
        require(future_time >= time_tem + MIN_RAMP_TIME, "Insufficient time");

        let initial_a_tem = ampl();
        require(future_a > 0 && future_a < MAX_A, "Invaild future a");
        require((future_a >= initial_a_tem && future_a <= initial_a_tem * MAX_A_CHANGE) || (future_a < initial_a_tem && future_a * MAX_A_CHANGE >= initial_a_tem), "Invaild a");
        storage.initial_A.write(initial_a_tem);
        storage.future_A.write(future_a);
        storage.initial_A_time.write(time_tem);
        storage.future_A_time.write(future_time);

        log(RampAEvent {
            old_A: initial_a_tem,
            new_A: future_a,
            initial_time: time_tem,
            future_time: future_time
        });
    }


    #[storage(read, write)]
    fn stop_ramp_a() {
        only_owner(msg_sender().unwrap());

        let current_a = ampl();
        let time_tem = (timestamp() % (2.pow(32))).as_u256();

        storage.initial_A.write(current_a);
        storage.future_A.write(current_a);
        storage.initial_A_time.write(time_tem);
        storage.future_A_time.write(time_tem);

        log(StopRampAEvent {
            A: current_a,
            time: time_tem
        });
    }


    #[storage(read)]
    fn get_balances(i: u64) -> u256 {
        let balances = storage.balances.read();
        match i {
            0 => balances.balance0,
            1 => balances.balance1,
            2 => balances.balance2,
            _ => revert(0),
        }
    }


    #[storage(read)]
    fn get_admin_balances(i: u64) -> u256 {
        let balances = storage.balances.read();
        let assets = storage.assets.read();

        match i {
            0 => this_balance(assets.asset0).as_u256() - balances.balance0,
            1 => this_balance(assets.asset1).as_u256() - balances.balance1,
            2 => this_balance(assets.asset2).as_u256() - balances.balance2,
            _ => revert(0),
        }
    }


    #[storage(read)]
    fn get_account_balances(account: Identity, i: u64) -> u256 {
        let cur_deposits = storage.deposits.get(account).try_read().unwrap_or(Deposited::zero());
        match i {
            0 => cur_deposits.asset0,
            1 => cur_deposits.asset1,
            2 => cur_deposits.asset2,
            _ => revert(0),
        }
    }


    #[storage(read)]
    fn get_total_supply() -> u256 {
        storage.total_supply.read()
    }


    #[storage(read)]
    fn withdraw_admin_fee() {
        let sender = msg_sender().unwrap();
        only_owner(sender);

        let balances = storage.balances.read();
        let assets = storage.assets.read();
        let mut i = 0;

        while i < to_u64(N_ASSET) {
            let (asset, value) = match i {
                0 => (assets.asset0, this_balance(assets.asset0).as_u256() - balances.balance0),
                1 => (assets.asset1, this_balance(assets.asset1).as_u256() - balances.balance1),
                2 => (assets.asset2, this_balance(assets.asset2).as_u256() - balances.balance2),
                _ => revert(0),
            };

            if value > 0 {
                transfer(sender, asset, to_u64(value));
            }
            i += 1;
        }
    }

    #[payable, storage(read, write)]
    fn deposit() {
        let sender = msg_sender().unwrap();
        let amount = msg_amount().as_u256();
        let asset_id = msg_asset_id();
        let assets = storage.assets.read();

        let old_deposited = storage.deposits.get(sender).try_read().unwrap_or(Deposited::zero());
        let mut new_deposited = old_deposited;
        let old_total_deposited = storage.user_total_deposited.get(sender).try_read().unwrap_or(Deposited::zero());
        let mut new_total_deposited = old_total_deposited;
        
        if asset_id == assets.asset0 {
            new_deposited.asset0 = old_deposited.asset0 + amount;
            new_total_deposited.asset0 = old_total_deposited.asset0 + amount;
        } else if asset_id == assets.asset1 {
            new_deposited.asset1 = old_deposited.asset1 + amount;
            new_total_deposited.asset1 = old_total_deposited.asset1 + amount;
        } else if asset_id == assets.asset2 {
            new_deposited.asset2 = old_deposited.asset2 + amount;
            new_total_deposited.asset2 = old_total_deposited.asset2 + amount;
        } else {
            revert(0);
        }
        storage.ass.write(asset_id);
        storage.deposits.insert(sender, new_deposited);
        storage.user_total_deposited.insert(sender, new_total_deposited);

        log(DepositEvent {
            sender: sender,
            amount: amount,
            asset: asset_id
        });
    }


    #[storage(read, write)]
    fn withdraw(amounts: Vec<u256>, assets: Vec<AssetId>) {
        require(amounts.len() == assets.len(), "Invaild lenght");

        let sender = msg_sender().unwrap();
        let deposit_tem = storage.deposits.get(sender).try_read().unwrap();
        let mut new_deposited = deposit_tem;
        let assets_tem = storage.assets.read();
        let mut i = 0;

        while i < assets.len() {
            let value = amounts.get(i).unwrap();
            let withdraw_asset = assets.get(i).unwrap();

            if withdraw_asset == assets_tem.asset0 {
                require(deposit_tem.asset0 >= value, "Insufficient amount");
                new_deposited.asset0 = deposit_tem.asset0 - value;
            } else if withdraw_asset == assets_tem.asset1 {
                require(deposit_tem.asset1 >= value, "Insufficient amount");
                new_deposited.asset1 = deposit_tem.asset1 - value;
            } else if withdraw_asset == assets_tem.asset2 {
                require(deposit_tem.asset2 >= value, "Insufficient amount");
                new_deposited.asset2 = deposit_tem.asset2 - value;
            } else {
                revert(0);
            }

            transfer(sender, withdraw_asset, to_u64(value));
            i += 1;
        }
        
        storage.deposits.insert(sender, new_deposited);

        log(WithdrawEvent {
            sender: sender,
            amounts: amounts,
            assets: assets
        });
    }


    #[storage(read, write)]
    fn kill_me() {
        only_owner(msg_sender().unwrap());
        storage.is_killed.write(true);
    }


    #[storage(read, write)]
    fn unkill_me() {
        only_owner(msg_sender().unwrap());
        storage.is_killed.write(false);
    }

    #[storage(read, write)]
    fn emergency_remove_liquidity(i: u256, amount: u64) {
        only_owner(msg_sender().unwrap());

        let mut input_asset = AssetId::zero();

        if i == 0 {
            input_asset = storage.assets.read().asset0;
        } else if i == 1 {
            input_asset = storage.assets.read().asset1;
        } else if i == 2 {
            input_asset = storage.assets.read().asset2;
        } else {
            revert(0);
        }

        transfer(msg_sender().unwrap(), input_asset, amount);
    }

}


#[storage(read)]
fn only_owner(sender: Identity) {
    let owner = storage.owner.read();
    require(owner == sender.as_address().unwrap(), "Only owner");
}


#[storage(read)]
fn ampl() -> u256 {
    let block_timestamp = timestamp() % (2.pow(32));
    let bt = block_timestamp.as_u256();
    let t1 = storage.future_A_time.read();
    let a1 = storage.future_A.read();
    let a0 = storage.initial_A.read();
    let t0 = storage.initial_A_time.read();
    
    match bt < t1 {
        true => {

            if a1 > a0 {
                a0 + (a1 - a0) * (bt - t0) / (t1 - t0)
            } else {
                a0 - (a0 - a1) * (bt - t0) / (t1 - t0)
            }
            
        },
        false => a1,
    }
}


#[storage(read)]
fn xp() -> Vec<u256> {
    let mut rates = RATES;
    let mut balances = storage.balances.read();
    let mut result = Vec::new();
    let mut i = 0;

    while i < 3 {
        let (rate, ban) = match i {
            0 => (rates.0, balances.balance0),
            1 => (rates.1, balances.balance1),
            2 => (rates.2, balances.balance2),
            _ => revert(0),
        };

        result.push((rate * ban / LENDING_PRECISION));
        i += 1;
    }

    result
}


fn xp_mem(balances: Balances) -> Vec<u256> {
    let mut rates = RATES;
    let mut result = Vec::new();
    let mut i = 0;

    while i < 3 {
        let (rate, ban) = match i {
            0 => (rates.0, balances.balance0),
            1 => (rates.1, balances.balance1),
            2 => (rates.2, balances.balance2),
            _ => revert(0),
        };

        result.push((rate * ban / PRECISION));
        i += 1;
    }

    result
}


fn get_d_invariant(xp_vec: Vec<u256>, amp: u256) -> u256 {
    let mut s: u256 = 0;

    for xv in xp_vec.iter() {
        s += xv;
    }

    if s == 0 {
        return 0;
    }

    let mut d_prev: u256 = 0;
    let mut d: u256 = s;
    let mut ann: u256 = amp * 3;
    let mut i = 0;

    while i < 255 {
        let mut d_p: u256 = d;

        for xv in xp_vec.iter() {
            d_p = d_p * d / (xv * 3u8.as_u256());
        }

        d_prev = d;
        d = (ann * s + d_p * 3u8.as_u256()) * d / ((ann - 1u8.as_u256()) * d + 4u8.as_u256() * d_p);

        if d > d_prev {
            if d - d_prev <= 1 {
                break
            }
        } else {
            if d_prev - d <= 1 {
                break
            }
        }
        i += 1;
    }

    d
}


fn get_d_invariant_mem(balances: Balances, amp: u256) -> u256 {
    get_d_invariant(xp_mem(balances), amp)
}


#[storage(read)]
fn get_y(
    i: u256, 
    j: u256, 
    x: u256, 
    xp_vec: Vec<u256>
) -> u256 {
    require(i != j && i >= 0 && j >= 0 && i < N_ASSET && j < N_ASSET, "Invalid params");
    
    let amp = ampl();
    let d = get_d_invariant(xp_vec, amp);
    let mut c = d;
    let mut s: u256 = 0;
    let ann = amp * N_ASSET;

    let mut _x: u256 = 0;
    let mut _i = 0;
    let i_64 = to_u64(i);
    let j_64 = to_u64(j);

    while _i < to_u64(N_ASSET) {
        if _i == i_64 {
            _x = x;
        } else if _i != j_64 {
            _x = xp_vec.get(_i).unwrap();
        } else {
            _i += 1;
            continue;
        }

        s += _x;
        c = c * d / (_x * N_ASSET);
        _i += 1;
    }

    c = c * d / (ann * N_ASSET);
    let b = s + d / ann;
    let mut y_prev: u256 = 0;
    let mut y: u256 = d;
    let mut w = 0;

    while w < 255 {
        y_prev = y;
        y = (y * y + c) / (2u8.as_u256() * y + b - d);

        if y > y_prev {
            if y - y_prev <= 1 {
                break;
            }
        } else {
            if y_prev - y <= 1 {
                break;
            }
        }
        w += 1;
    }

    y

}


fn get_y_d(a: u256, i: u256, xp_vec: Vec<u256>, d: u256) -> u256 {
    require(i >= 0 && i < N_ASSET, "invaild i");

    let mut c: u256 = d;
    let mut s: u256 = 0;
    let ann: u256 = a * N_ASSET;

    let mut x: u256 = 0;
    let mut ii: u256 = 0;
    let u64_i = to_u64(i);

    while ii < N_ASSET {
        if ii != i {
            x = xp_vec.get(to_u64(ii)).unwrap();
        } else {
            ii += 1;
            continue;
        }

        s += x;
        c = c * d / (x * N_ASSET);
        ii += 1;
    }

    c = c * d / (ann * N_ASSET);
    let b = s + d / ann;
    let mut y_prev: u256 = 0;
    let mut y = d;
    ii = 0;

    while ii < 255 {
        y_prev = y;
        y = (y * y + c) / (2u8.as_u256() * y + b - d);
        if y > y_prev {
            if y - y_prev <= 1 {
                break;
            }
        } else {
            if y_prev - y <= 1 {
                break;
            }
        }
        ii += 1;
    }

    y
    
}

#[storage(read)]
fn calc_withdraw_one_asset_internal(asset_amount: u256, i: u256) -> (u256, u256) {
    let amp = ampl();
    let fee = storage.fee.read() * N_ASSET / (4u8.as_u256() * (N_ASSET - 1u8.as_u256()));
    let precision_tem = match i {
        INDEX_0 => PRECISION_MUL.0,
        INDEX_1 => PRECISION_MUL.1,
        INDEX_2 => PRECISION_MUL.2,
        _ => revert(0),
    };
    let total_supply = storage.total_supply.read();
    let xp_tem = xp();

    let d0 = get_d_invariant(xp_tem, amp);
    let d1 = d0 - asset_amount * d0 / total_supply;

    let new_y = get_y_d(amp, i, xp_tem, d1);
    let dy_0 = (xp_tem.get(to_u64(i)).unwrap() - new_y) / precision_tem;

    let mut j: u256 = 0;
    let mut xp_reduced: Vec<u256> = Vec::new();

    while j < N_ASSET {
        let mut dx_expected: u256 = 0;
        let xp_unwrap = xp_tem.get(to_u64(j)).unwrap();
        if j == i {
            dx_expected = xp_unwrap * d1 / d0 - new_y;
        } else {
            dx_expected = xp_unwrap - xp_unwrap * d1 / d0;
        }
        xp_reduced.push(xp_unwrap - fee * dx_expected / FEE_DENOMINATOR);
        j += 1;
    }

    let mut dy = xp_reduced.get(to_u64(i)).unwrap() - get_y_d(amp, i, xp_reduced, d1);
    dy = (dy - 1) / precision_tem;

    (dy, dy_0 - dy)
}


fn to_u64(amount: u256) -> u64 {
    let u64_value: Option<u64> = <u64 as TryFrom<u256>>::try_from(amount);
    u64_value.unwrap_or(0)
}


#[storage(read)]
fn convert_liquidity_amount_u64(amount: u256) -> u64 {
    let ratio: u256 = (amount * RATIO_PRECISION) / MAX_TOTAL_SUPPLY;
    to_u64(ratio * MAX_U64 / RATIO_PRECISION - 1)
}