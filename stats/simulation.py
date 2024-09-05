import numpy as np
import matplotlib.pyplot as plt
from matplotlib import ticker as mticker
import seaborn as sns
from math import sqrt
from numba import njit, float64
from numba.experimental import jitclass
from amm import AMM
import click


class Simulation:
    def __init__(self,
                 initial_price: float,
                 daily_sigma: float,
                 blocks_per_day: int,
                 days: int,
                 gas_cost: float,
                 liquidity_per_basis_point: float,
                 pool_fee: float,
                 paths: int) -> None:
        self.initial_price = 1200
        self.daily_sigma = 0.05
        self.blocks_per_day = 60 * 60 * 24 / 13.2
        self.days = 365
        self.gas_cost = gas_cost
        self.liquidty_per_basis_point = liquidity_per_basis_point
        self.pool_fee = pool_fee
        self.paths = paths
       
    @njit
    def do_simulation(self) -> np.ndarray:
        """
        # This array will store three values for each simulated price path:
        (0) lvr (as a positive number),
        (1) arb's gain (negative),
        (2) total gas burned
        """
        results = np.zeros((3, self.paths))
       
        for j in range(self.paths):
            # save the initial price
            p0 = self.initial_price
            # volatility @ block level
            sigma = self.daily_std/np.sqrt(self.blocks_per_day)
            total_number_of_blocks = int(self.days * self.blocks_per_day)
            z = np.cumsum(np.random.normal(0.0, sigma, total_number_of_blocks))
            # adding a risk-neutral drift, so that the price process is a martingale
            prices = np.exp(z - (np.arange(total_number_of_blocks) * sigma**2)/2)
            prices = (prices / prices[0]) * p0

            amm = AMM(sqrt_price,
                      self.pool_fee, self.liquidty_per_basis_point,
                      base_fee=0.003,
                      m=0.5,
                      n=2,
                      alpha=0.5,
                      liquidity_threshold=100,
                      intent_threshold=0.95)
            loss_versus_rebalancing = 0.0
            arbitrage_gain = 0.0
            gas = 0.0
            for k in range(1, total_number_of_blocks):
                number_of_swaps_in_block_k = 100 # randomize on a grid
                for s in range(1, number_of_swaps_in_block_k):
                    x0, y0, f = amm.trade_to_price_with_gas_fee(prices[k], self.gas_cost)
                    loss_versus_rebalancing += -x0 * prices[k] - y0
                    if x0 != 0.0:
                        arbitrage_gain += x0 * prices[k] + y0 - self.gas_cost
                        gas += self.gas_cost

            results[:, k] = [loss_versus_rebalancing/days, arbitrage_gain/days, gas/days]
        return results
