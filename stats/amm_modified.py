import numpy as np
import requests
import math
import logging
from functools import cache

class AMM:
    def __init__(self,
                sqrt_price,
                 pool_fee,
                 L,
                 base_fee=0.003,
                 m=0.5,
                 n=2, alpha=0.5, liquidity_threshold=100, intent_threshold=0.95, cex_api_url="https://api.cex.io/api/order_book/BTC/USD/"):
        self.logger = logging.getLogger(__class__.__name__)
        self.sqrt_price = sqrt_price
        self.pool_fee = pool_fee
        self.L = L
        self.base_fee = base_fee
        self.cut_off_percentile = 0.85
        self.m = m
        self.n = n
        self.alpha = alpha  # Weight for endogenous fee
        self.liquidity_threshold = liquidity_threshold  # Threshold for low liquidity
        self.intent_threshold = intent_threshold  # Threshold for intent to trade
        self.cex_api_url = cex_api_url  # URL to fetch order book data from CEX
       
        self.previous_block_swappers = set()  # Set to store swappers who submitted a delta in the previous block
        self.first_transaction = True  # Flag to track the first transaction
        self.swapper_intent = {}  # Dictionary to track intent to trade
        self.total_blocks = 0  # Total number of blocks
        self.order_book_data = None  # Store order book data

        # block price:
        self.price_before_block_t_minus_1 = 997
        self.price_after_block_t_minus_1 = 1000
        self.slippage = 0

        # submitted fee
        self.submitted_fees_multiple_threshold = 3
        self.submitted_fees = []

    @cache
    def endogenous_dynamic_fee(self, block_id: int) -> float:
        # endogenous fees - price based on beginning block t-1 and end block t-1
        price_impact = abs(self.price_after_block_t_minus_1 - self.price_before_block_t_minus_1) / self.price_before_block_t_minus_1
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

        # Check for low liquidity and high slippage
        # first transaction is on a pool by pool basis - not yet included
        if self.first_transaction and (self.x < self.liquidity_threshold or self.y < self.liquidity_threshold):
            self.slippage = abs(self.price_x_after_swap - self.price_x_before_swap) / self.price_x_before_swap
            if (self.slippage > 0.01):  # Example threshold for high slippage 1%
                combined_fee *= 2  # Charge/double higher fee for the first transaction
            self.first_transaction = False
       
        # Check for continuous intent to trade
        # might include pool_id to identify other types of pools for instance meme pools
        # swapper intent -> laas
        if swapper_id in self.swapper_intent:
            intent_rate = self.swapper_intent[swapper_id] / self.total_blocks
            if intent_rate >= self.intent_threshold:
                # Apply additional discount for loyal swapper addresses in dict
                combined_fee *= 0.9
        return combined_fee

    def trade_x_for_y(self,
                      efficient_price: float|None,
                      submitted_fee: float|None,
                      swapper_id: int|None):
        """
        sell X tokens for Y tokens    
        Returns:
            x, y, fee: The amounts of X and Y tokens traded and the fee.
        """
        new_sqrt_price = math.sqrt(efficient_price * (1 - self.pool_fee))
        x = self.calculate_x(new_sqrt_price)
        y = self.calculate_y(new_sqrt_price)
        return (x, y/(1 - self.pool_fee), y * self.pool_fee)

    def trade_y_for_x(self,
                      efficient_price: float|None,
                      submitted_fee: float|None,
                      swapper_id: int|None):
        """
        buy X tokens for Y tokens
        Returns:
            x, y, fee: The amounts of X and Y tokens traded and the fee.
        """
        new_sqrt_price = math.sqrt(efficient_price / (1 - self.pool_fee))
        x = self.calculate_x(new_sqrt_price)
        y = self.calculate_y(new_sqrt_price)
        return (x, y/(1 - self.pool_fee), -y * self.pool_fee * (1 - self.pool_fee))

    def fetch_order_book_data(self):
        try:
            response = requests.get(self.cex_api_url)
            if response.status_code == 200:
                self.order_book_data = response.json()
            else:
                print(f"Failed to fetch order book data: {response.status_code}")
        except Exception as e:
            print(f"Error fetching order book data: {e}")

    # where is the emm price on the cex going
    # chainlink or via own oracle
    # increasing protocol feels and share part with chainlink for getting data
    def process_order_book_data(self):
        if self.order_book_data:
            # Example processing: Calculate L1 and L2 pressure
            bids = self.order_book_data['bids']
            asks = self.order_book_data['asks']
            l1_bid_pressure = sum([float(bid[1]) for bid in bids[:1]])
            l1_ask_pressure = sum([float(ask[1]) for ask in asks[:1]])
            l2_bid_pressure = sum([float(bid[1]) for bid in bids[:2]])
            l2_ask_pressure = sum([float(ask[1]) for ask in asks[:2]])
            return l1_bid_pressure, l1_ask_pressure, l2_bid_pressure, l2_ask_pressure
        return None, None, None, None

    # definition, when this is called, basically last transactional swap call
    def end_block(self):
        # Fetch and process order book data at the beginning of each block
        self.fetch_order_book_data()
        l1_bid_pressure, l1_ask_pressure, l2_bid_pressure, l2_ask_pressure = self.process_order_book_data()
        print(f"L1 Bid Pressure: {l1_bid_pressure}, L1 Ask Pressure: {l1_ask_pressure}")
        print(f"L2 Bid Pressure: {l2_bid_pressure}, L2 Ask Pressure: {l2_ask_pressure}")

        # Clear the submitted fees at the end of each block
        self.submitted_fees = []
        # Clear the previous block swappers list
        self.previous_block_swappers = set()
        # Increment the total number of blocks
        self.total_blocks += 1
        # Reset the first transaction flag
        self.first_transaction = True

    def calculate_x(self, new_sqrt_price: float) -> float:
        """
        Calculate the amount of X tokens involved in the swap.
        Args:
            new_sqrt_price (float): The new square root price after the swap.
        Returns:
            float: The amount of X tokens.
        """
        self.price_x_before_swap = self.sqrt_price**2
        # ToDo: Check if this is correct?
        self.price_x_after_swap = new_sqrt_price**2
        return (new_sqrt_price - self.sqrt_price) * self.L / (self.sqrt_price * new_sqrt_price)

    def calculate_y(self, new_sqrt_price: float) -> float:
        """
        Calculate the amount of Y tokens involved in the swap.
        Args:
            new_sqrt_price (float): The new square root price after the swap.
        Returns:
            float: The amount of Y tokens.
        """
        return -(new_sqrt_price - self.sqrt_price) * self.L
   
    def trade_to_price_with_gas_fee(self,
                                    efficient_price: float,
                                    submitted_fee: float|None,
                                    swapper_id: float|None,
                                    block_id: int,
                                    gas: float=0.0,
                                    informed: bool=True):
        """
        Attempts to perform a swap and/or submit-delta bid given the market price and gas fee
        Args:
            efficient_price (float):
                The efficient price towards which the trade will be performed.
                If it exceeds the current pool price of X,
                the function will attempt to buy X for the client (the pool will be selling X).
                The swap must be profitable to the client after the swap fee and gas cost.
            gas (float, optional): total gas cost of the transaction in Y tokens. Defaults to 0.0.
            informed (bool, optional): flag to indicate if the trade is informed (arbitrage) or uninformed. Defaults to True.
        Returns:
            x, y, fee:
                If a profitable arbitrage opportunity is found,
                then it is executed against the pool.
                Return values x and y are positive if the client receives
                the corresponding amount and negative otherwise.
                x and y already include the swap fee, but not the gas fee.
               
                III: The third return, fee, is for informational purposes and is measured in Y tokens.
                If no profitable swap is found and the trade is informed,
                the state of the pool is unchanged, and the function returns three zeros.
        """
        current_price = self.sqrt_price**2
        if submitted_fee is not None:
            if submitted_fee < 0:
                self.logger.info("Submitted fee must be non-negative.")
            if submitted_fee > self.base_fee * self.submitted_fees_multiple_threshold:
                self.logger.info(f"Submitted fee cannot exceed {self.submitted_fees_multiple_threshold} times the base fee.")
            self.submitted_fees.append(submitted_fee)
        if swapper_id is not None:
            self.previous_block_swappers.add(swapper_id)
            if swapper_id not in self.swapper_intent:
                self.swapper_intent[swapper_id] = 0
            self.swapper_intent[swapper_id] += 1
        if informed:
            if (current_price / (1 - self.pool_fee) > efficient_price) and (current_price * (1 - self.pool_fee) < efficient_price):
                # efficient price is within the current bid-ask spread, no arb opportunity available
                return (0, 0, 0)
            elif (current_price / (1 - self.pool_fee) < efficient_price):
                # efficient price is higher than best ask,
                # try buying X for the client (the pool sells)
                x, y, fee = self.trade_y_for_x(efficient_price, gas)
            else:
                # efficient price is lower than best bid,
                # try selling X for the client (the pool buys)
                x, y, fee = self.trade_x_for_y(efficient_price, gas)
        else:
            # Uninformed trade
            if (current_price / (1 - self.pool_fee) < efficient_price):
                new_sqrt_price = math.sqrt(efficient_price * (1 - self.pool_fee))
            else:
                new_sqrt_price = math.sqrt(efficient_price / (1 - self.pool_fee))
        # Calculate the amounts and fee
        x = self.calculate_x(new_sqrt_price)
        y = self.calculate_y(new_sqrt_price)
        fee = gas
        return (x, y, fee)

    def calculate_dynamic_fee(self, trade_direction: str):
        l1_bid_pressure, l1_ask_pressure = self.process_order_book_data()
        if trade_direction == 'buy' and l1_ask_pressure > l1_bid_pressure:
            return self.base_fee * 1.5  
        elif trade_direction == 'sell' and l1_bid_pressure > l1_ask_pressure:
            return self.base_fee * 1.5  
        else:
            return self.base_fee * 0.5
