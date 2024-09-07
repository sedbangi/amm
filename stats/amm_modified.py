mport numpy as np
import math
import logging
from functools import cache
from strategies.dynamic_fees.price_feed import PriceFeed

class AMM:
    def __init__(self,
                 price,
                 L: float=166_666.67,
                 base_fee=0.003,
                 m=0.5,
                 n=2,
                 alpha=0.5,
                 intent_threshold=0.95) -> None:
        self.logger = logging.getLogger(__class__.__name__)
        self.sqrt_price = math.sqrt(price)
        # block:
        self.current_block_id = None
        self.price_before_previous_block = int(price * 0.995)
        self.price_after_previous_block = price
        self.slippage = 0

        self.L = L
        self.base_fee = base_fee
       
        self.cut_off_percentile = 0.85
        self.m = m
        self.n = n
        self.alpha = alpha  # Weight for endogenous fee
        # Threshold for intent to trade
        self.intent_threshold = intent_threshold  
        # Set to store swappers who submitted a delta in the previous block
        self.previous_block_swappers = set()
        # Flag to track the first transaction
        self.first_transaction = True  
        # Dictionary to track intent to trade
        self.swapper_intent = {}
        # Total number of blocks
        self.total_blocks = 0  
       
        # NOTE: mocking chain_link price feed from CEX
        self.price_feed = PriceFeed()

        # submitted fee
        self.submitted_fees_multiple_threshold = 3
        self.submitted_fees = []

    @cache
    def endogenous_dynamic_fee(self, block_id: int) -> float:
        if block_id == 0:
            return self.base_fee
        price_impact = abs(self.price_after_previous_block -
                           self.price_before_previous_block) / self.price_before_previous_block
        dynamic_fee = self.base_fee + price_impact * 0.01  # Example: 1% of price impact
        return dynamic_fee

    def exogenous_dynamic_fee(self, swapper_id: int|None):
        # exogenous fees - submitted fees ordered
        if len(self.submitted_fees) < 2:
            return self.base_fee
        sorted_fees = sorted(self.submitted_fees)
        # constant set in constructor to 0.85 - first time, will be amended top 15% will be discarded
        cutoff_index = int(len(sorted_fees) * self.cut_off_percentile)
        filtered_fees = sorted_fees[:cutoff_index]
        mean_fee = np.mean(filtered_fees)
        sigma_fee = np.std(filtered_fees)
        # identifies if former intent also led to swap loyal LT - to be improved by LaaS
        if swapper_id in self.previous_block_swappers:
            # Discounted fee
            dynamic_fee = mean_fee + self.m * sigma_fee  
        else:
            # Regular fee
            dynamic_fee = self.n * sigma_fee  
        return dynamic_fee

    def calculate_combined_fee(self, block_id, swapper_id):
        combined_fee = self.alpha * self.endogenous_dynamic_fee(block_id=block_id) +\
            (1 -  self.alpha) * self.exogenous_dynamic_fee(swapper_id)
        combined_fee = max(combined_fee, self.endogenous_dynamic_fee(block_id=block_id))
        # Adjust cut-off percentile
        if combined_fee <= (self.base_fee * 1.25):
            # 1 - no VCG auction everybody participates
            self.cut_off_percentile = min(self.cut_off_percentile + 0.05, 1.0)
        if combined_fee > self.base_fee * 2: # set by AMM how aggressive
            self.cut_off_percentile = max(self.cut_off_percentile - 0.05, 0.5)

        # first transaction is on a pool by pool basis - not yet included
        if self.first_transaction:
            combined_fee *= 5  # Charge higher fee for the first transaction
            self.first_transaction = False
        # NOTE: unhandled case: -> high gas fees.
       
        # Check for continuous intent to trade
        # might include pool_id to identify other types of pools for instance meme pools
        # swapper intent -> laas
        if swapper_id in self.swapper_intent:
            intent_rate = self.swapper_intent[swapper_id] / self.total_blocks
            if intent_rate >= self.intent_threshold:
                # NOTE: Apply additional discount for loyal swapper addresses in dict
                # NOTE: mocking brevis
                combined_fee *= 0.9
        return combined_fee
   
    def buy_x_tokens_for_y_tokens(self,
                                  new_sqrt_price: float,
                                  pool_fee_plus_one: float):
        """
        Returns:
            x, y, fee: The amounts of X and Y tokens traded and the fee.
        """
        x = self.calculate_amount_x_tokens_involved_in_swap(new_sqrt_price)
        y = self.calculate_amount_of_y_tokens_involved_in_swap(new_sqrt_price)
        return (x,
                y * pool_fee_plus_one,
                -y * (pool_fee_plus_one - 1))

    def sell_x_tokens_for_y_tokens(self,
                                   new_sqrt_price: float,
                                   pool_fee_plus_one: float):
        """
        Returns:
            x, y, fee: The amounts of X and Y tokens traded and the fee.
        """
        x = self.calculate_amount_x_tokens_involved_in_swap(new_sqrt_price)
        y = self.calculate_amount_of_y_tokens_involved_in_swap(new_sqrt_price)
        return (x,
                y * (2 - pool_fee_plus_one),
                (y - y *(2 - pool_fee_plus_one)))

    def calculate_amount_x_tokens_involved_in_swap(self, new_sqrt_price: float) -> float:
        """
        Args:
            new_sqrt_price (float): The new square root price after the swap.
        Returns:
            float: The amount of X tokens.
        """
        self.price_x_before_swap = self.sqrt_price**2
        self.price_x_after_swap = new_sqrt_price**2
        return (new_sqrt_price - self.sqrt_price) * self.L / (self.sqrt_price * new_sqrt_price)

    def calculate_amount_of_y_tokens_involved_in_swap(self, new_sqrt_price: float) -> float:
        """
        Args:
            new_sqrt_price (float): The new square root price after the swap.
        Returns:
            float: The amount of Y tokens.
        """
        return -(new_sqrt_price - self.sqrt_price) * self.L
   
    @cache
    def get_bid_and_ask_of_amm(self, current_amm_price: float):
        """
        Get the bid and ask prices of the AMM.
        Returns:
            float, float: The bid and ask prices.
        """
        bid_price = current_amm_price * (2 - (1 + self.base_fee))
        ask_price = current_amm_price * (1+ self.base_fee)
        return bid_price, ask_price

    def trade_to_price_with_gas_fee(self,
                                    efficient_off_chain_price: float,
                                    submitted_fee: float|None,
                                    swapper_id: float|None,
                                    block_id: int,
                                    gas: float=0.0,
                                    informed: bool=True):
        if not self.current_block_id:
            self.current_block_id = block_id
            self.begin_block(block_id=block_id)
        elif self.current_block_id != block_id:
            # NOTE: in python, end_block called
            # at the beginning of first swap of the next block
            self.end_block()
            self.current_block_id += 1
            self.begin_block()
   
        if self.current_block_id == 0:
            self.pool_fee = 1 + self.base_fee
        else:
            delta = self.calculate_combined_fee(block_id, swapper_id) - self.base_fee
            self.pool_fee_in_market_direction = self.pool_fee + delta
            self.pool_fee_in_opposite_direction = self.pool_fee - delta
       
        current_amm_price = self.sqrt_price**2
        amm_bid_price, amm_ask_price = self.get_bid_and_ask_of_amm(current_amm_price)
        if submitted_fee is not None:
            if submitted_fee < 0:
                self.logger.info("Submitted fee must be non-negative.")
            if submitted_fee > self.base_fee * self.submitted_fees_multiple_threshold:
                self.logger.info(f"Submitted fee cannot exceed {self.submitted_fees_multiple_threshold}\
                                 times the base fee.")
            self.submitted_fees.append(submitted_fee)
        if swapper_id is not None:
            self.previous_block_swappers.add(swapper_id)
            if swapper_id not in self.swapper_intent:
                self.swapper_intent[swapper_id] = 0
            self.swapper_intent[swapper_id] += 1
        # TODO: flush the history of swapper intent after a certain number of blocks
        if informed:
            if (amm_ask_price > efficient_off_chain_price) and (amm_bid_price < efficient_off_chain_price):
                # efficient price is within the current bid-ask spread, no arb opportunity available
                # no swap is performed -> hence sqrt_price remains the same
                return (0, 0, 0)    
        """
        other cases are common to informed and uninfored traders:
        # Uninformed trader:
        will trade even if there is no arbitrage opportunity
        """
        if (amm_ask_price < efficient_off_chain_price):
            if self.order_bool_pressure > 0:
                # market-makers are quoting  large quantities at the ask price
                _fee =  1 + self.pool_fee_in_market_direction
            elif self.order_bool_pressure < 0:
                # market-makers are quoting  large quantities at the bid price
                _fee = 1 + self.pool_fee_in_opposite_direction
            else:
                _fee = 1 + self.base_fee
            new_sqrt_price = math.sqrt(efficient_off_chain_price / _fee)
            x, y, fee = self.buy_x_tokens_for_y_tokens(new_sqrt_price=new_sqrt_price,
                                                        pool_fee_plus_one=_fee)
        elif (amm_bid_price > efficient_off_chain_price):
            if self.order_bool_pressure > 0:
                _fee =  1 + self.pool_fee_in_opposite_direction
            elif self.order_bool_pressure < 0:
                _fee = 1 + self.pool_fee_in_market_direction
            else:
                _fee = 1 + self.base_fee
            new_sqrt_price = math.sqrt(efficient_off_chain_price * (2 - _fee))
            x, y, fee = self.sell_x_tokens_for_y_tokens(new_sqrt_price=new_sqrt_price,
                                                        pool_fee_plus_one=_fee)
        if gas > (x * efficient_off_chain_price + y):
            self.logger.info(f"block_id: {block_id}, swapper_id {swapper_id}:\
                             gas cost cannot exceed the total value of the trade.")
            (x, y, fee) = (0, 0, 0)
        else:
            self.sqrt_price = new_sqrt_price
        return (x, y, fee)
   
    @cache
    def begin_block(self, block_id: int):
        self.logger.info(f"Beginning block {block_id}.")
        try:
            self.order_bool_pressure = self.price_feed.l1_order_book_pressure()
        except Exception as e:
            #TODO: include error handing for broken price_feed in solidity
            self.logger.exception(f"{e}")
       
    def end_block(self):
        """
        # when this is called, basically last transactional swap call
        """
        # Clear the submitted fees at the end of each block
        self.submitted_fees = []
        # Clear the previous block swappers list
        self.previous_block_swappers = set()
        # Increment the total number of blocks
        self.total_blocks += 1
        # Reset the first transaction flag
        self.first_transaction = True
