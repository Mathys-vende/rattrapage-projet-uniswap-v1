import pytest
from test.pool import Pool

eth_reserve = 123.005071763679216071
usdc_reserve = 453_357.751946

def test_pool_constant():
  assert Pool(eth_reserve, usdc_reserve, 0.3).k() == eth_reserve * usdc_reserve



@pytest.mark.parametrize("fee_percent", [0.0, 0.05, 0.3, 1.0])
def test_pool_fee_factor(fee_percent):
  assert Pool(eth_reserve, usdc_reserve, fee_percent).fee_factor() == 1 - fee_percent / 100

def test_pool_spot_price():
  pool = Pool(eth_reserve, usdc_reserve, 0.0)
  assert pool.x_spot_price() == usdc_reserve / eth_reserve
  assert pool.y_spot_price() == eth_reserve / usdc_reserve


@pytest.mark.parametrize("fee_percent", [0.0, 0.05, 0.3, 1.0])
def test_pool_swap_eth_for_usdc(fee_percent):
  pool = Pool(eth_reserve, usdc_reserve, fee_percent)
  k_before = pool.k()
  eth_in = 1
  usdc_out = pool.swap_x_for_y(eth_in)
  if fee_percent == 0:
    assert usdc_out == 3655.9613691444392
  else:
    # Result should be same as pool with 0% fee, but with fee applied to input
    assert usdc_out == Pool(eth_reserve, usdc_reserve, 0.0).swap_x_for_y(eth_in * pool.fee_factor())
  assert pool.x == eth_reserve + eth_in
  assert pool.y == usdc_reserve - usdc_out

  if fee_percent == 0:
    assert pool.k() == k_before
  else:
    # Liquidity should increase, as fees are compounded
    assert pool.k() > k_before


@pytest.mark.parametrize("fee_percent", [0.0, 0.05, 0.3, 1.0])
def test_pool_swap_usdc_for_eth(fee_percent):
  pool = Pool(eth_reserve, usdc_reserve, fee_percent)
  k_before = pool.k()
  usdc_in = 3655.9613691444392
  eth_out = pool.swap_y_for_x(usdc_in)
  if fee_percent == 0:
    assert eth_out == 0.9840006491593982
  else:
    # Result should be same as pool with 0% fee, but with fee applied to input
    assert eth_out == Pool(eth_reserve, usdc_reserve, 0.0).swap_y_for_x(usdc_in * pool.fee_factor())
  assert pool.x == eth_reserve - eth_out
  assert pool.y == usdc_reserve + usdc_in

  if fee_percent == 0:
    assert pool.k() == k_before
  else:
    # Liquidity should increase, as fees are compounded
    assert pool.k() > k_before

