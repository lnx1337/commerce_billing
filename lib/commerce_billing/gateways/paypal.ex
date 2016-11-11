defmodule Commerce.Billing.Gateways.Paypal do
  use Commerce.Billing.Gateways.Base
  
  import Poison, only: [decode!: 1]
  
  alias Commerce.Billing.{
    CreditCard,
    Address
  }
  
  alias Commerce.Billing.HttpRequest
  
  @base_url "https://api.sandbox.paypal.com/v1"
  
  def init(config) do
    body = %{grant_type: "client_credentials"}
    
    request =
      HttpRequest.new(:post, "#{@base_url}/oauth2/token")
      |> HttpRequest.put_body(body, :url_encoded)
      |> HttpRequest.put_auth(:basic, config.credentials)
    
    case HttpRequest.send(request) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          config =
            body
            |> decode!
            |> Map.get("access_token")
            |> put_access_token(config)
            
          {:ok, config}
      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:stop, "Unexpected #{code} http status code returned requesting access_token"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:stop, reason}
    end
  end
  
  def purchase(amount, card_or_id, opts) do
    params = %{}
      |> put_intent(:sale)
      |> put_payer(card_or_id, opts)
      |> put_transactions(amount, opts)

    commit(:post, "/payments/payment", params, opts)
  end
  
  defp commit(method, path, params, opts) do
    {:ok, config} = Keyword.fetch!(opts, :config)
    token = config.access_token
      
    method
      |> HttpRequest.new("#{@base_url}#{path}")
      |> HttpRequest.put_body(params, :json)
      |> HttpRequest.put_auth(:bearer, token)
      |> HttpRequest.send
      |> respond
  end

  defp respond({:ok, %{status_code: 200, body: body}}) do
    IO.puts(body)
    {:ok}
  end

  defp respond({:ok, %{status_code: status_code, body: body}}) do
    IO.puts(status_code)
    IO.puts("******************")
    IO.puts(body)
    {:ok}
  end

  defp put_access_token(token, config),
    do: Map.put(config, :access_token, token)

  defp put_intent(map, :sale),
    do: Map.put(map, :intent, "sale")
    
  defp put_payer(map, card_or_id, opts) do
    payer =
      Map.new
      |> Map.put(:payment_method, "credit_card")
      |> put_funding_instruments(card_or_id, opts)
    
    Map.put(map, :payer, payer)
  end
  
  defp put_funding_instruments(map, card, opts) do
    credit_card =
      Map.new
      |> put_credit_card(card, opts)
    
    Map.put(map, :funding_instruments, [credit_card])
  end
  
  defp put_credit_card(map, card = %CreditCard{}, opts) do
    {expire_year, expire_month} = card.expiration
    {holder_first, holder_last} = card.holder
  
    credit_card = %{
      type: card.brand,
      number: card.number,
      expire_year: expire_year,
      expire_month: expire_month,
      cvv2: card.cvc,
      first_name: holder_first,
      last_name: holder_last
    }
    |> put_billing_address(opts)
      
    Map.put(map, :credit_card, credit_card)
  end
  
  defp put_billing_address(map, opts) do
    opts_address = Keyword.get(opts, :billing_address)
    
    address = %{
      line1: opts_address.street1,
      line2: opts_address.street2,
      city: opts_address.city,
      country_code: opts_address.country,
      state: opts_address.region,
    }
    
    Map.put(map, :billing_address, address)
  end
  
  defp put_transactions(map, amount, opts) do
    {:ok, config} = Keyword.fetch!(opts, :config)
    currency = Keyword.get(opts, :currency, config.default_currency)
    amount = money_to_cents(amount)
    
    # TODO: add support for tax and shipping costs
    amount_map = %{
      total: amount,
      currency: currency,
      details: %{
        subtotal: amount,
        tax: 0,
        shipping: 0
      }
    }
    
    Map.put(map, :transactions, [%{amount: amount_map}])
  end
end