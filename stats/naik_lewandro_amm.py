import numpy as np
import requests
import math

class AMM:
    def __init__(self, 
                sqrt_price,
                 pool_fee, 
                 L, 
                 base_fee=0.003, 
                 m=0.5, 
                 n=2, alpha=0.5, liquidity_threshold=100, intent_threshold=0.95, cex_api_url="https://api.cex.io/api/order_book/BTC/USD/"):
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
        self.submitted_fees = []  # List to store submitted fees from swappers
        self.previous_block_swappers = set()  # Set to store swappers who submitted a delta in the previous block
        self.first_transaction = True  # Flag to track the first transaction
        self.swapper_intent = {}  # Dictionary to track intent to trade
        self.total_blocks = 0  # Total number of blocks
        self.order_book_data = None  # Store order book data

    def x_price(self):
        return self.sqrt_price**2

    def y_price(self):
        return self.sqrt_price**2

    # dx - swap amount - token0
    # submitted fee - delta
    # swapper id - EOA
    # normal swap or submit delta or both
    def trade_x(self, dx=None, submitted_fee=None, swapper_id=None):
        if submitted_fee is not None:
            self.submitted_fees.append(submitted_fee)
        if swapper_id is not None:
            self.previous_block_swappers.add(swapper_id)
            if swapper_id not in self.swapper_intent:
                self.swapper_intent[swapper_id] = 0
            self.swapper_intent[swapper_id] += 1
        if dx is not None:
            fee_percentage = self.calculate_combined_fee(swapper_id, dx, 'x')
            fee_adjusted_dx = dx * (1 - fee_percentage)
            dy = -self.y * fee_adjusted_dx / (self.x + fee_adjusted_dx)
            self.x += dx
            self.y += dy
            return dy
        return None

    # dy - swap amount - token1
    # submitted fee - delta
    # swapper id - EOA
    # normal swap or submit delta or both
    def trade_y(self, dy=None, submitted_fee=None, swapper_id=None):
        if submitted_fee is not None:
            self.submitted_fees.append(submitted_fee)
        if swapper_id is not None:
            self.previous_block_swappers.add(swapper_id)
            if swapper_id not in self.swapper_intent:
                self.swapper_intent[swapper_id] = 0
            self.swapper_intent[swapper_id] += 1
        if dy is not None:
            fee_percentage = self.calculate_combined_fee(swapper_id, dy, 'y')
            fee_adjusted_dy = dy * (1 - fee_percentage)
            dx = -self.x * fee_adjusted_dy / (self.y + fee_adjusted_dy)
            self.x += dx
            self.y += dy
            return dx
        return None

    # 2 types of fees
    # endogenous fees - price based on beginning block t-1 and end block t-1 - lovelace approach
    def endogenous_dynamic_fee(self, price_before, price_after):
        price_impact = abs(price_after - price_before) / price_before
        dynamic_fee = self.base_fee + price_impact * 0.01  # Example: 1% of price impact
        return dynamic_fee

    # 2 types of fees
    # exogenous fees - submitted fees ordered 
    def exogenous_dynamic_fee(self, swapper_id):
        if len(self.submitted_fees) < 2:
            return self.base_fee
        sorted_fees = sorted(self.submitted_fees)
        cutoff_index = int(len(sorted_fees) * self.cut_off_percentile) # constant set in constructor to 0.85 - first time, will be amended top 15% will be discarded
        filtered_fees = sorted_fees[:cutoff_index]
        mean_fee = np.mean(filtered_fees)
        sigma_fee = np.std(filtered_fees)
        if swapper_id in self.previous_block_swappers: # identifies if former intent also led to swap loyal LT - to be improved by LaaS
            dynamic_fee = mean_fee + self.m * sigma_fee  # Discounted fee
        else:
            dynamic_fee = self.n * sigma_fee  # Regular fee
        return dynamic_fee



    def calculate_combined_fee(self, swapper_id, amount, trade_type):
        # Calculate endogenous fee
        price_before = self.x_price() if trade_type == 'x' else self.y_price()
        price_after = self.y_price() if trade_type == 'x' else self.x_price()
        endogenous_fee = self.endogenous_dynamic_fee(price_before, price_after)
       
        # Calculate exogenous fee
        exogenous_fee = self.exogenous_dynamic_fee(swapper_id)
       
        # Combine fees
        beta = 1 - self.alpha # weight between end/exo
        combined_fee = self.alpha * endogenous_fee + beta * exogenous_fee # combination
       
        # Floor by endogenous fee
        combined_fee = max(combined_fee, endogenous_fee,00)
       
        # Adjust cut-off percentile
        if endogenous_fee < self.base_fee:
            self.cut_off_percentile = min(self.cut_off_percentile + 0.05, 1.0) # 1 - no VCG auction everybody participates
        if exogenous_fee > self.base_fee * 2: # set by AMM how aggressive
            self.cut_off_percentile = max(self.cut_off_percentile - 0.05, 0.5)

        # Check for low liquidity and high slippage
        # first transaction is on a pool by pool basis - not yet included
        if self.first_transaction and (self.x < self.liquidity_threshold or self.y < self.liquidity_threshold):
            slippage = abs(price_after - price_before) / price_before
            if (slippage > 0.01):  # Example threshold for high slippage 1%
                combined_fee *= 2  # Charge/double higher fee for the first transaction
            self.first_transaction = False
       
        # Check for continuous intent to trade
        # might include pool_id to identify other types of pools for instance meme pools
        # swapper intent -> laas 
        if swapper_id in self.swapper_intent:
            intent_rate = self.swapper_intent[swapper_id] / self.total_blocks
            if intent_rate >= self.intent_threshold:
                combined_fee *= 0.9  # Apply additional discount for loyal swapper addresses in dict
       
        return combined_fee

    def trade_x_for_y(self, dx, submitted_fee=None, swapper_id=None):
        dy = self.trade_x(dx, submitted_fee, swapper_id)
        return dy

    def trade_y_for_x(self, dy, submitted_fee=None, swapper_id=None):
        dx = self.trade_y(dy, submitted_fee, swapper_id)
        return dx

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

    # difference between arbitrage and non-arbitrage swapper - nezlobin
    def trade_to_price_with_gas_fee(self, efficient_price: float, gas: float = 0.0) -> tuple[float, float, float]:
        """
        Attempts to perform an arbitrage swap given the market price and gas fee.
       
        Args:
            efficient_price (float):
                The efficient price towards which the trade will be performed.
                If it exceeds the current pool price of X,
                the function will attempt to buy X for the client (the pool will be selling X).
                The swap must be profitable to the client after the swap fee and gas cost.
            gas (float, optional): total gas cost of the transaction in Y tokens. Defaults to 0.0.
        Returns:
            x, y, fee:
                If a profitable arbitrage opportunity is found,
                then it is executed against the pool.
                Return values x and y are positive if the client receives
                the corresponding amount and negative otherwise.
                x and y already include the swap fee,
                but not the gas fee.
                The third return, fee, is for informational purposes and is measured in Y tokens.
                If no profitable swap is found,
                the state of the pool is unchanged, and the function returns three zeros.
        """
        current_price = self.sqrt_price**2
        if (current_price / (1 - self.pool_fee) > efficient_price) and (current_price * (1 - self.pool_fee) < efficient_price):
            # efficient price is within the current bid-ask spread,
            # no arb opportunity available
            (x, y, fee) = (0, 0, 0)
            new_sqrt_price = self.sqrt_price
        elif (current_price / (1 - self.pool_fee) < efficient_price):
            # efficient price is higher than best ask,
            # try buying X for the client (the pool sells)
            new_sqrt_price = math.sqrt(efficient_price * (1 - self.pool_fee))
            y = -(new_sqrt_price - self.sqrt_price) * self.L
            (x, y, fee) = (
                (new_sqrt_price - self.sqrt_price) * self.L / (self.sqrt_price * new_sqrt_price),
                y / (1 - self.pool_fee),
                -y * self.pool_fee * (1 - self.pool_fee)
            )
        else:
            new_sqrt_price = math.sqrt(efficient_price / (1 - self.pool_fee))
            y = -(new_sqrt_price - self.sqrt_price) * self.L
            (x, y, fee) = (
                (new_sqrt_price - self.sqrt_price) * self.L / (self.sqrt_price * new_sqrt_price),
                y * (1 - self.pool_fee),
                y * self.pool_fee
            )
       
        if (x * efficient_price + y < gas):
            # The arb opportunity does not justify the gas fee
            (x, y, fee) = (0.0, 0.0, 0.0)
        else:
            self.sqrt_price = new_sqrt_price
        return (x, y, fee)

    def informed_trade(self, efficient_price: float, gas: float = 0.0) -> tuple[float, float, float]:
        return self.trade_to_price_with_gas_fee(efficient_price, gas)

    def uninformed_trade(self, dx=None, dy=None, submitted_fee=None, swapper_id=None):
        if dx is not None:
            return self.trade_x(dx, submitted_fee, swapper_id)
        if dy is not None:
            return self.trade_y(dy, submitted_fee, swapper_id)
        return None

    def calculate_dynamic_fee(self, trade_direction: str):
        l1_bid_pressure, l1_ask_pressure, l2_bid_pressure, l2_ask_pressure = self.process_order_book_data()
        if trade_direction == 'buy' and l1_ask_pressure > l1_bid_pressure:
            return self.base_fee * 1.5  # Increase fee for buying when ask pressure is higher
        elif trade_direction == 'sell' and l1_bid_pressure > l1_ask_pressure:
            return self.base_fee * 1.5  # Increase fee for selling when bid pressure is higher
        else:
            return self.base_fee * 0.5  # Decrease fee for the opposite direction

    def trade_with_dynamic_fee(self, dx=None, dy=None, trade_direction=None, swapper_id=None):
        dynamic_fee = self.calculate_dynamic_fee(trade_direction)
        if dx is not None:
            fee_adjusted_dx = dx * (1 - dynamic_fee)
            dy = -self.y * fee_adjusted_dx / (self.x + fee_adjusted_dx)
            self.x += dx
            self.y += dy
            return dy
        if dy is not None:
            fee_adjusted_dy = dy * (1 - dynamic_fee)
            dx = -self.x * fee_adjusted_dy / (self.y + fee_adjusted_dy)
            self.x += dx
            self.y += dy
            return dx
        return None
