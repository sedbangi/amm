import random

class PriceFeed:
    def __init__(self,
                 efficient_off_chain_price: float) -> None:
        self.efficient_off_chain_price = efficient_off_chain_price
        self.half_spread = 0.005
   
    def simulate_l1_order_book(self) -> None:
        self.bid_size = random.randint(1, 1000)
        self.bid_price = self.efficient_off_chain_price * (1 - self.half_spread)
        self.ask_price = self.efficient_off_chain_price * (1 + self.half_spread)
        self.ask_size = random.randint(1, 1000)
        while self.ask_size == self.bid_size:
            self.ask_size = random.randint(1, 1000)

    def l1_order_book_pressure(self) -> float:
        return (self.ask_size * self.ask_price - self.bid_size * self.bid_price) /\
            (self.ask_size * self.ask_price + self.bid_size * self.bid_price)
