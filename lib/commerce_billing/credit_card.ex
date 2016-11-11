defmodule Commerce.Billing.CreditCard do
  defstruct [:number, :expiration, :cvc, :brand, :holder]
end
