#[test_only]
use sui::coin::{Self, Coin};
#[test_only]
use sui::sui::SUI;
#[test_only]
use sui::test_scenario::{Self as ts, Scenario};

#[test_only]
use escrow::lock;

#[test_only]
const ALICE: address = @0xA;
#[test_only]
const BOB: address = @0xB;
#[test_only]
const DIANE: address = @0xD;

#[test_only]
fun test_coin(ts: &mut Scenario): Coin<SUI> {
		coin::mint_for_testing<SUI>(42, ts.ctx())
}
#[test]
fun test_successful_swap() {
		let mut ts = ts::begin(@0x0);

		let (i2, ik2) = {
				ts.next_tx(BOB);
				let c = test_coin(&mut ts);
				let cid = object::id(&c);
				let (l, k) = lock::lock(c, ts.ctx());
				let kid = object::id(&k);
				transfer::public_transfer(l, BOB);
				transfer::public_transfer(k, BOB);
				(cid, kid)
		};

		let i1 = {
				ts.next_tx(ALICE);
				let c = test_coin(&mut ts);
				let cid = object::id(&c);
				create(c, ik2, BOB, ts.ctx());
				cid
		};

		{
				ts.next_tx(BOB);
				let escrow: Escrow<Coin<SUI>> = ts.take_shared();
				let k2: Key = ts.take_from_sender();
				let l2: Locked<Coin<SUI>> = ts.take_from_sender();
				let c = escrow.swap(k2, l2, ts.ctx());

				transfer::public_transfer(c, BOB);
		};
		ts.next_tx(@0x0);

		{
				let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, i2);
				ts::return_to_address(ALICE, c);
		};

		{
				let c: Coin<SUI> = ts.take_from_address_by_id(BOB, i1);
				ts::return_to_address(BOB, c);
		};

		ts::end(ts);
}

#[test]
#[expected_failure(abort_code = EMismatchedSenderRecipient)]
fun test_mismatch_sender() {
		let mut ts = ts::begin(@0x0);

		let ik2 = {
				ts.next_tx(DIANE);
				let c = test_coin(&mut ts);
				let (l, k) = lock::lock(c, ts.ctx());
				let kid = object::id(&k);
				transfer::public_transfer(l, DIANE);
				transfer::public_transfer(k, DIANE);
				kid
		};

		{
				ts.next_tx(ALICE);
				let c = test_coin(&mut ts);
				create(c, ik2, BOB, ts.ctx());
		};

		{
				ts.next_tx(DIANE);
				let escrow: Escrow<Coin<SUI>> = ts.take_shared();
				let k2: Key = ts.take_from_sender();
				let l2: Locked<Coin<SUI>> = ts.take_from_sender();
				let c = escrow.swap(k2, l2, ts.ctx());

				transfer::public_transfer(c, DIANE);
		};

		abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_mismatch_object() {
		let mut ts = ts::begin(@0x0);

		{
				ts.next_tx(BOB);
				let c = test_coin(&mut ts);
				let (l, k) = lock::lock(c, ts.ctx());
				transfer::public_transfer(l, BOB);
				transfer::public_transfer(k, BOB);
		};

		{
				ts.next_tx(ALICE);
				let c = test_coin(&mut ts);
				let cid = object::id(&c);
				create(c, cid, BOB, ts.ctx());
		};

		{
				ts.next_tx(BOB);
				let escrow: Escrow<Coin<SUI>> = ts.take_shared();
				let k2: Key = ts.take_from_sender();
				let l2: Locked<Coin<SUI>> = ts.take_from_sender();
				let c = escrow.swap(k2, l2, ts.ctx());

				transfer::public_transfer(c, BOB);
		};

		abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_object_tamper() {
		let mut ts = ts::begin(@0x0);

		let ik2 = {
				ts.next_tx(BOB);
				let c = test_coin(&mut ts);
				let (l, k) = lock::lock(c, ts.ctx());
				let kid = object::id(&k);
				transfer::public_transfer(l, BOB);
				transfer::public_transfer(k, BOB);
				kid
		};

		{
				ts.next_tx(ALICE);
				let c = test_coin(&mut ts);
				create(c, ik2, BOB, ts.ctx());
		};

		{
				ts.next_tx(BOB);
				let k: Key = ts.take_from_sender();
				let l: Locked<Coin<SUI>> = ts.take_from_sender();
				let mut c = lock::unlock(l, k);

				let _dust = c.split(1, ts.ctx());
				let (l, k) = lock::lock(c, ts.ctx());
				let escrow: Escrow<Coin<SUI>> = ts.take_shared();
				let c = escrow.swap(k, l, ts.ctx());

				transfer::public_transfer(c, BOB);
		};

		abort 1337
}

#[test]
fun test_return_to_sender() {
		let mut ts = ts::begin(@0x0);

		let cid = {
				ts.next_tx(ALICE);
				let c = test_coin(&mut ts);
				let cid = object::id(&c);
				let i = object::id_from_address(@0x0);
				create(c, i, BOB, ts.ctx());
				cid
		};

		{
				ts.next_tx(ALICE);
				let escrow: Escrow<Coin<SUI>> = ts.take_shared();
				let c = escrow.return_to_sender(ts.ctx());

				transfer::public_transfer(c, ALICE);
		};

		ts.next_tx(@0x0);

		{
				let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, cid);
				ts::return_to_address(ALICE, c)
		};

		ts::end(ts);
}

#[test]
#[expected_failure]
fun test_return_to_sender_failed_swap() {
		let mut ts = ts::begin(@0x0);

		let ik2 = {
				ts.next_tx(BOB);
				let c = test_coin(&mut ts);
				let (l, k) = lock::lock(c, ts.ctx());
				let kid = object::id(&k);
				transfer::public_transfer(l, BOB);
				transfer::public_transfer(k, BOB);
				kid
		};

		{
				ts.next_tx(ALICE);
				let c = test_coin(&mut ts);
				create(c, ik2, BOB, ts.ctx());
		};

		{
				ts.next_tx(ALICE);
				let escrow: Escrow<Coin<SUI>> = ts.take_shared();
				let c = escrow.return_to_sender(ts.ctx());
				transfer::public_transfer(c, ALICE);
		};

		{
				ts.next_tx(BOB);
				let escrow: Escrow<Coin<SUI>> = ts.take_shared();
				let k2: Key = ts.take_from_sender();
				let l2: Locked<Coin<SUI>> = ts.take_from_sender();
				let c = escrow.swap(k2, l2, ts.ctx());

				transfer::public_transfer(c, BOB);
		};

		abort 1337
}