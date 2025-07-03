#[test_only]
use sui::coin::{Self, Coin};
#[test_only]
use sui::sui::SUI;
#[test_only]
use sui::test_scenario::{Self as ts, Scenario};

#[test_only]
fun test_coin(ts: &mut Scenario): Coin<SUI> {
		coin::mint_for_testing<SUI>(42, ts.ctx())
}

#[test]
fun test_lock_unlock() {
		let mut ts = ts::begin(@0xA);
		let coin = test_coin(&mut ts);

		let (lock, key) = lock(coin, ts.ctx());
		let coin = lock.unlock(key);

		coin.burn_for_testing();
		ts.end();
}