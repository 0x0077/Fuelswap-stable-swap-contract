library;

use std::{
    block::timestamp,
    u128::U128,
    vec::Vec
};

use ::structs::Balances;


pub fn ampl(
    t0: u256, 
    t1: u256, 
    a0: u256, 
    a1: u256
) -> u256 {
    let block_timestamp = timestamp();

    match block_timestamp < t1 {
        true => {

            if a1 > a0 {
                a0 + (a1 - a0) * (block_timestamp - t0) / (t1 - t0)
            } else {
                a0 - (a0 - a1) * (block_timestamp - t0) / (t1 - t0)
            }
            
        },
        false => a1,
    }
}


pub fn xp(rates: (u256, u256, u256), lending_precision: u256, balances: Balances) -> Vec<u256> {
    let mut result = Vec::new();
    let mut i = 0;

    while i < 3 {
        let (rate, ban) = match i {
            0 => (rates.0, balances.balance0),
            1 => (rates.1, balances.balance1),
            2 => (rates.2, balances.balance2),
            _ => revert(0),
        };

        result.push((rate * ban / lending_precision));
        i += 1;
    }

    result
}


pub fn xp_mem(rates: (u256, u256, u256), precision: u256, balances: Balances) -> Vec<u256> {
    let mut result = Vec::new();
    let mut i = 0;

    while i < 3 {
        let (rate, ban) = match i {
            0 => (rates.0, balances.balance0),
            1 => (rates.1, balances.balance1),
            2 => (rates.2, balances.balance2),
            _ => revert(0),
        };

        result.push((rate * ban / precision));
        i += 1;
    }

    result
}


pub fn get_d_invariant(xp_vec: Vec<u256>, amp: u256) -> u256 {
    let mut s = 0;

    for xv in xp_vec.iter() {
        s += xv;
    }

    if s == 0 {
        return 0;
    }

    let mut d_prev = 0;
    let mut d = s;
    let mut ann = amp * 3;
    let mut i = 0;

    while i < 255 {
        let mut d_p = d;

        for xv in xp_vec.iter() {
            d_p = d_p * d / (xv * 3);
        }

        d_prev = d;
        d = (ann * s + d_p * 3) * d / ((ann - 1) * d + 4 * d_p);

        if d > d_prev {
            if d - d_prev <= 1 {
                break
            }
        } else {
            if d_prev - d <= 1 {
                break
            }
        }
    }

    d
}


pub fn get_d_invariant_mem(rates: (u256, u256, u256), precision: u256, balances: Balances, amp: u256) -> u256 {
    get_d_invariant(xp_mem(rates, precision, balances), amp)
}


pub fn get_y(
    i: u256, 
    j: u256, 
    x: u256, 
    xp_vec: Vec<u256>,
    amp: u256
) -> u256 {
    require(i != j && i >= 0 && j >= 0 && i < 3 && j < 3, "Invalid params");
    
    let d = get_d_invariant(xp_vec, amp);
    let mut c = d;
    let mut s = 0;
    let ann = amp * 3;

    let mut _x = 0;
    let mut _i = 0;
    while _i < 3 {
        if _i == i {
            _x = x;
        } else if _i != j {
            _x = xp_vec.get(_i).unwrap();
        } else {
            continue;
        }

        s += _x;
        c = c * d / (_x * 3);
        _i += 1;
    }

    c = c * d / (ann *3);
    let b = s + d / ann;
    let mut y_prev = 0;
    let mut y = d;
    let mut w = 0;

    while w < 255 {
        y_prev = y;
        y = (y * y + c) / (2 * y + b -d);

        if y > y_prev {
            if y - y_prev <= 1 {
                break;
            }
        } else {
            if y_prev - y <= 1 {
                break;
            }
        }
    }

    y

}