from dataclasses import dataclass

@dataclass
class Pool:
  x: float
  y: float
  fee_percent: float

  def k(self) -> float:
    pass # TODO: implement this => should return the constant k = x * y

  def fee_factor(self) -> float:
    pass # TODO: implement this => should return the fee factor (100 - fee_percent) / 100

  def swap_x_for_y(self, x_in: float) -> float:
    pass # TODO: implement this => should return the amount of y received and update reserves

  def swap_y_for_x(self, y_in: float) -> float:
    pass # TODO: implement this => should return the amount of x received and update reserves

  def x_spot_price(self) -> float:
    pass # TODO: implement this => should return the spot price of x in terms of y

  def y_spot_price(self) -> float:
    pass # TODO: implement this => should return the spot price of y in terms of x
