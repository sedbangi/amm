class PriceFeed:
    def __init__(self,
                 bid_size: int,
                 bid_price: float,
                 ask_price: float,
                 ask_size: int) -> None:
        self.bid_size = bid_size
        self.bid_price = bid_price
        self.ask_price = ask_price
        self.ask_size = ask_size

    def l1_order_book_pressure(self) -> float:
        return (self.ask_size * self.ask_price - self.bid_size * self.bid_price) /\
            (self.ask_size * self.ask_price + self.bid_size * self.bid_price)
