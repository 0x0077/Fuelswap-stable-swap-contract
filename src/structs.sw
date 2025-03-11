library;

pub struct Amounts {
    pub amount0: u256,
    pub amount1: u256,
    pub amount2: u256
}

pub struct Fees {
    pub fee0: u256,
    pub fee1: u256,
    pub fee2: u256
}

pub struct Assets {
    pub asset0: AssetId,
    pub asset1: AssetId,
    pub asset2: AssetId
}

pub struct Balances {
    pub balance0: u256,
    pub balance1: u256,
    pub balance2: u256
}

pub struct Deposited {
    pub asset0: u256,
    pub asset1: u256,
    pub asset2: u256
}


impl Assets {
    pub fn new(asset0: AssetId, asset1: AssetId, asset2: AssetId) -> Self {
        Self { asset0, asset1, asset2 }
    }

    pub fn zero() -> Self {
        Self {
            asset0: AssetId::zero(), 
            asset1: AssetId::zero(), 
            asset2: AssetId::zero(),
        }
    }
}


impl Balances {
    pub fn new(balance0: u256, balance1: u256, balance2: u256) -> Self {
        Self { balance0, balance1, balance2 }
    }

    pub fn zero() -> Self {
        Self { 
            balance0: 0, 
            balance1: 0, 
            balance2: 0,
        }
    }
}


impl Deposited {
    pub fn zero() -> Self {
        Self {
            asset0: 0,
            asset1: 0,
            asset2: 0,
        }
    }
}