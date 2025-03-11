use fuels::{
    accounts::wallet, 
    prelude::*, 
    types::{
        Address, 
        Bytes32,
        AssetId,
        Identity,
        ContractId,
        bech32::{
            Bech32Address
        },
        U256
    }
};
use std::str::FromStr;
use fuels::programs::responses::CallResponse;


// Load abi from json
abigen!(Contract(
    name = "StableSwap",
    abi = "out/debug/StableSwap-abi.json"
));


async fn get_contract_instance() -> (StableSwap<WalletUnlocked>, Bech32ContractId, Vec<WalletUnlocked>) {
    // Launch a local network and deploy the contract
    let mut wallets = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(2),             /* Single wallet */
            Some(1),             /* Single coin (UTXO) */
            Some(1_000_000_000_000_000_000), /* Amount per coin */
        ),
        None,
        None,
    )
    .await
    .unwrap();

    let num_assets = 5;
    let coins_per_asset = 1;
    let amount_per_coin = 18_446_744_073_709_551_615;

    let mut coins = Vec::new();
    let mut _asset_ids = Vec::new();

    for wallet in &mut wallets {
        (coins, _asset_ids) = setup_multiple_assets_coins(
            wallet.address(),
            num_assets,
            coins_per_asset,
            amount_per_coin,
        );

        let provider = setup_test_provider(coins.clone(), vec![], None, None).await;
        wallet.set_provider(provider.expect("aaa"));
    }

    let wallet_0 = wallets.get(0).unwrap().clone();

    let id = Contract::load_from(
        "./out/debug/StableSwap.bin",
        LoadConfiguration::default(),
    )
    .unwrap()
    .deploy(&wallet_0, TxPolicies::default())
    .await
    .unwrap();

    let instance = StableSwap::new(id.clone(), wallet_0.clone());

    (instance, id, wallets)
}


async fn to_u256(amount: u64) -> U256 {
    U256::from(amount)
}


#[tokio::test]
async fn can_get_contract_id() -> Result<()>{
    let (contract, id, wallets) = get_contract_instance().await;

    let wallet_0 = wallets.get(0).unwrap();
    let a = to_u256(2000).await;
    let fee = to_u256(1000000).await;
    let admin_fee = to_u256(5000000000).await;

    let wallet_bans = wallet_0.get_balances().await?;
    let assets: Vec<String> = wallet_bans.keys().cloned().collect();

    let token0 = AssetId::from_str(assets.get(1).unwrap()).expect("a");
    let token1 = AssetId::from_str(assets.get(2).unwrap()).expect("b");
    let token2 = AssetId::from_str(assets.get(3).unwrap()).expect("c");

    let init_assets = Assets {
        asset_0: token0,
        asset_1: token1,
        asset_2: token2
    };

    // println!("tokens::: {:?}", init_assets);

    contract
        .clone()
        .methods()
        .init(init_assets, a, fee, admin_fee)
        .with_variable_output_policy(VariableOutputPolicy::Exactly(3))
        .call()
        .await?;

    let get_a = contract
        .methods()
        .get_ampl()
        .call()
        .await?
        .value;
    
    println!("A 的值: {:?}", get_a);


    let amount = 1_446_744_073_709_551_615;
    // let call_params1 = CallParameters::new(amount, token0, 1_000_000);
    // let call_params2 = CallParameters::new(amount, token1, 1_000_000);
    // let tx_policies = TxPolicies::default();

    // let contract_methods = contract.methods();
    // let tx1 = contract_methods.deposit().with_tx_policies(tx_policies).call_params(call_params1);
    // let tx2 = contract_methods.deposit().with_tx_policies(tx_policies).call_params(call_params2);
    // let mut multi_call = MultiContractCallHandler::new(wallet_0.clone());

    let tx_policies = TxPolicies::default().with_script_gas_limit(1_000_000);

    for i in 1..4 {
        let token = AssetId::from_str(assets.get(i).unwrap()).expect("a");
        let call_param = CallParameters::new(amount, token, 1_000_000);
        
        contract
            .methods()
            .deposit()
            .with_tx_policies(tx_policies)
            .call_params(call_param)
            .expect("a")
            .call()
            .await?;
    }


    let amount_vec: Vec<U256> = vec![
        U256::from(446_744_073_709_551_615u64),
        U256::from(446_744_073_709_551u64),
        U256::from(446_744_073_709_551u64),
    ];

    contract
        .methods()
        .add_liquidity(amount_vec, U256::from(0), wallet_0.address())
        .with_tx_policies(tx_policies)
        .with_variable_output_policy(VariableOutputPolicy::Exactly(4))
        .call()
        .await?;
    

    // 29887296595862179717777465
    // 551323311358920319601350291171
    let total_supply_after = contract
        .methods()
        .get_total_supply()
        .call()
        .await?
        .value;

    println!("初始化流动性后 total supply: {:?}", total_supply_after);

    let amount_vec2: Vec<U256> = vec![
        U256::from(46_744_073_709_551_615u64),
        U256::from(46_744_073_709_551u64),
        U256::from(146_744_073_709_551u64),
    ];

    contract
        .methods()
        .add_liquidity(amount_vec2, U256::from(0), wallet_0.address())
        .with_tx_policies(tx_policies)
        .with_variable_output_policy(VariableOutputPolicy::Exactly(4))
        .call()
        .await?;

    let dy_i = U256::from(0);
    let dy_j = U256::from(2);
    let dy_dx = U256::from(1000000000000u64);
    let dy = contract
        .methods()
        .get_dy(dy_i, dy_j, dy_dx)
        .simulate(Execution::StateReadOnly)
        .await?
        .value;

    println!("预估 dy--:::: {:?}", dy);

    // let ban_before = wallet_0.get_balances().await?;
    // println!("提款 before:: {:?}", ban_before);

    // let ec_withdraw = contract
    //     .methods()
    //     .emergency_remove_liquidity(U256::from(0), 19950910)
    //     .with_variable_output_policy(VariableOutputPolicy::Exactly(3))
    //     .call()
    //     .await?;

    // println!("---:::: {:?}", ec_withdraw);

    // let ban_before1 = wallet_0.get_balances().await?;
    // println!("提款 after:: {:?}", ban_before1);
    // let swap_call_params = CallParameters::new(100000000000, token1, 1_000_000);

    // swap
    // let swap_res = contract
    //     .methods()
    //     .swap(dy_i, dy_j, dy_dx, U256::from(0))
    //     .with_tx_policies(tx_policies)
    //     .call_params(swap_call_params)
    //     .expect("a")
    //     .with_variable_output_policy(VariableOutputPolicy::Exactly(4))
    //     .call()
    //     .await?;
    
    // println!("swap result:::: {:?}", swap_res);

    // remove liquidity
    let remove_amount = U256::from(63552848170988183928u128);
    let remove_min_amounts: Vec<U256> = vec![
        U256::from(6_744_073_709_551_615u64),
        U256::from(6_744_073_709_551u64),
        U256::from(6_744_073_709_551u64),
    ];

    let calc_remove_liqui = contract
        .methods()
        .calc_token_amount(remove_min_amounts.clone(), false)
        .simulate(Execution::StateReadOnly)
        .await?
        .value;

    println!("calc remove liquidity ::::  {:?}", calc_remove_liqui);
    println!("-----------------------------------------------");
    println!("-----------------------------------------------");

    let calc_liqui = contract
        .methods()
        .get_liquidity_from_u256(U256::from(20232260007796001630338616u128))
        .simulate(Execution::StateReadOnly)
        .await?
        .value;

    println!("预估流动性值 : {:?}", calc_liqui);
    println!("-----------------------------------------------");
    println!("-----------------------------------------------");
    
    // let calc_one_asset = contract
    //     .methods()
    //     .calc_withdraw_one_asset(U256::from(99661889787576891793u128), U256::from(0))
    //     .simulate(Execution::StateReadOnly)
    //     .await?
    //     .value;

    // println!("预估移除单个coin的值 : {:?}", calc_one_asset);
    // println!("-----------------------------------------------");
    // println!("-----------------------------------------------");

    let liqui_asset = contract
        .methods()
        .get_asset_id()
        .simulate(Execution::StateReadOnly)
        .await?
        .value;

    println!("{:?}", liqui_asset);
    let remove_tx_policies = TxPolicies::default();
    let remove_call_params = CallParameters::new(calc_liqui, liqui_asset, 1_000_000);

    let remove_min_amounts0: Vec<U256> = vec![
        U256::from(0),
        U256::from(0),
        U256::from(0),
    ];

    contract
        .methods()
        .remove_liquidity(calc_remove_liqui.1, remove_min_amounts0)
        .with_tx_policies(remove_tx_policies)
        .call_params(remove_call_params)
        .expect("remove")
        .with_variable_output_policy(VariableOutputPolicy::Exactly(4))
        .call()
        .await?;

    // let ban_after = wallet_0.get_balances().await?;
    // println!("swap after:: {:?}", ban_after);
    // println!("-----------------------------------------------");
    // println!("-----------------------------------------------");

    // // let remove_min_liqui: Vec<U256> = vec![
    // //     U256::from(17_346_744_073_709_551_615u64),
    // //     U256::from(17_346_744_073_709_551_615u64),
    // //     U256::from(17_346_744_073_709_551_615u64),
    // // ];

    // contract
    //     .methods()
    //     .remove_liquidity_one_asset(U256::from(99661889787576891793u128), U256::from(0), calc_one_asset * 99 / 100)
    //     .with_tx_policies(remove_tx_policies)
    //     .call_params(remove_call_params)
    //     .expect("remove")
    //     .with_variable_output_policy(VariableOutputPolicy::Exactly(4))
    //     .call()
    //     .await?;


    let ban_after = wallet_0.get_balances().await?;
    println!("remove liquidity before:: {:?}", ban_after);
    // println!("-----------------------------------------------");
    // println!("-----------------------------------------------");




    Ok(())

}


