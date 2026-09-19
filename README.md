
# defillama

**DefiLlama is the most widely used free tracker of where money sits and
moves in decentralised finance (DeFi) — the corner of crypto where
lending, trading, and saving happen through open software rather than
through a company.** It answers questions like how many dollars are
deposited in each app and on each blockchain, how much of each
stablecoin (a crypto token meant to hold a steady value, usually one US
dollar) is in circulation, how much trading the decentralised exchanges
do, and how much those apps earn in fees. This package pulls all of that
into clean tables you can work with in R, with no sign-up or key
required. It reports DefiLlama’s numbers faithfully and leaves the
interpretation to you.

## Technical overview

R API wrapper to the [DefiLlama](https://defillama.com) API supporting
both synchronous and asynchronous (promise based) operations. Provides
keyless R6 classes for stablecoin circulating supply, protocol and chain
TVL, DEX volumes, and protocol fees and revenue, built on the shared
[connectcore](https://github.com/dereckscompany/connectcore) transport
base.

DefiLlama is the leading open aggregator of on-chain crypto data: how
much value is locked in every DeFi protocol and on every chain (TVL),
how much every stablecoin has in circulation, how much volume
decentralised exchanges trade, and how much fees and revenue protocols
earn. It is a documented, **keyless** public JSON API. This package
gives you those series as tidy `data.table`s, both synchronously and
asynchronously, with typed errors and a faithful, low-level shape.

It is a faithful wrapper: it keeps DefiLlama’s field names
(snake_cased), unwraps its peculiar peg-nested amount format, and
returns clean tables — but it does not editorialise the data.

## Design philosophy

- **`data.table` everywhere, no list columns.** Every method returns one
  flat `data.table`; measurement columns (supplies, TVL, volumes, fees)
  are typed nullable because DefiLlama omits fields freely, structural
  columns strict.
- **Sync and async.** Every request-making surface works in both modes.
  `async = TRUE` returns a
  [promise](https://rstudio.github.io/promises/); otherwise the table is
  returned directly. There is a single sync/async branch point
  (inherited from `connectcore`).
- **Keyless.** DefiLlama’s public endpoints need no API key, so nothing
  is ever required or read.
- **Typed errors.** Every failure is a classed condition
  (`defillama_api_error`, `defillama_validation_error`) carrying
  structured fields — you branch on the type, never grep the message.

## Installation

This project uses [`renv`](https://rstudio.github.io/renv/). Add
`defillama` to your lockfile and restore:

``` r
renv::install("dereckscompany/defillama")
# or, without renv:
# remotes::install_github("dereckscompany/defillama")
```

## Stablecoins

Every tracked stablecoin with its current circulating supply and price.
DefiLlama nests each amount under its **peg type** key
(e.g. `peggedUSD`); the wrapper unwraps the value and records the peg
type in a `peg_type` column.

``` r
sc <- DefiLlamaStablecoins$new()

stablecoins <- sc$get_stablecoins()
stablecoins[, .(symbol, peg_mechanism, circulating, price)]
```

    #>    symbol peg_mechanism circulating price
    #>    <char>        <char>       <num> <num>
    #> 1:   USDT   fiat-backed       1e+11     1
    #> 2:    DAI crypto-backed       5e+09    NA

The full daily circulating-supply history of one stablecoin (by
pegged-asset id) comes in a single call. The optional supply measures
(`total_unreleased`, `total_minted_usd`, `total_bridged_to_usd`) are
present on only a minority of days — an absent measure is `NA`, never
`0`, so a genuine zero and a missing value stay distinguishable:

``` r
sc$get_stablecoin_charts(stablecoin_id = 1)
```

    #>    stablecoin_id   datetime  peg_type total_circulating total_circulating_usd
    #>           <char>     <POSc>    <char>             <num>                 <num>
    #> 1:             1 2024-01-01 peggedUSD               100                   101
    #> 2:             1 2024-01-02 peggedUSD               200                   202
    #>    total_unreleased total_minted_usd total_bridged_to_usd
    #>               <num>            <num>                <num>
    #> 1:               NA               NA                   NA
    #> 2:                5                0                    0

`get_stablecoin_chains()` gives the current stablecoin market cap per
chain.

## Protocol and chain TVL

The list of every DeFi protocol with its current total value locked. A
protocol with no locked value (e.g. a pure DEX) legitimately reports
`NA` TVL, and a multi-chain protocol has an `NA` singular `chain` (see
the `chains` column instead):

``` r
tvl <- DefiLlamaProtocols$new()

protocols <- tvl$get_protocols()
protocols[, .(name, category, chain, chains, tvl)]
```

    #>       name category    chain                 chains     tvl
    #>     <char>   <char>   <char>                 <char>   <num>
    #> 1: AAVE V3  Lending Ethereum       Ethereum;Polygon 1.5e+10
    #> 2: Uniswap    Dexes     <NA> Ethereum;Arbitrum;Base      NA

`get_protocol("aave")` returns one protocol’s full historical TVL,
`get_chains()` the current TVL of every chain, and
`get_historical_chain_tvl("Ethereum")` (or no argument for the whole
DeFi aggregate) a chain’s historical TVL.

## DEX volumes

The per-DEX volume breakdown — one row per protocol with trailing
24h/7d/30d/1y/all-time totals. The `data_type` argument selects the
volume series; the `data_type` column records which, so the table stays
self-describing:

``` r
vol <- DefiLlamaVolumes$new()

dexs <- vol$get_dexs_overview()
dexs[, .(name, data_type, total24h, total7d, total_all_time)]
```

    #>       name   data_type total24h total7d total_all_time
    #>     <char>      <char>    <num>   <num>          <num>
    #> 1: Uniswap dailyVolume  2.9e+09 1.4e+10        3.7e+12
    #> 2:  NewDex dailyVolume       NA      NA        5.0e+06

`get_dexs_chart()` returns the aggregate daily DEX-volume time series.

## Fees and revenue

The fees adapter shares the shape but a distinct domain: the `data_type`
selector switches the totals between fees paid (`dailyFees`), protocol
revenue (`dailyRevenue`), and holders’ revenue (`dailyHoldersRevenue`):

``` r
fees <- DefiLlamaFees$new()

fees$get_fees_overview(data_type = "dailyRevenue")[, .(name, data_type, total24h, total_all_time)]
```

    #>      name    data_type total24h total_all_time
    #>    <char>       <char>    <num>          <num>
    #> 1:   AAVE dailyRevenue   930000     1000000000
    #> 2: NoData dailyRevenue       NA         123456

`get_fees_chart()` returns the aggregate daily fees time series.

## Asynchronous usage

Set `async = TRUE` and consume the promise with `coro::async` / `await`,
driving the event loop with `later`:

``` r
box::use(coro, later)

sc_async <- DefiLlamaStablecoins$new(async = TRUE)

main <- coro::async(function() {
    charts <- await(sc_async$get_stablecoin_charts(stablecoin_id = 1))
    print(charts)
})

main()
while (!later::loop_empty()) later::run_now()
```

## Error handling

Every failure is a classed condition. An invalid `data_type` is caught
locally before any request; a DefiLlama HTTP error (e.g. an unknown
protocol slug) surfaces as a typed `defillama_api_error` carrying its
`status`:

``` r
result <- tryCatch(
    vol$get_dexs_overview(data_type = "not_a_real_type"),
    defillama_validation_error = function(e) paste("caught:", conditionMessage(e))
)
result
```

    #> [1] "caught: Invalid data_type 'not_a_real_type'. Valid values: dailyVolume, totalVolume."

## Documentation

The rendered reference site is at
[dereckscompany.github.io/defillama](https://dereckscompany.github.io/defillama).

The full release history is in [`NEWS.md`](NEWS.md).

## Citation

Cite as:

> Mezquita, D. (2026). defillama: API Wrapper to the DefiLlama API. R
> package version 0.1.3. <https://github.com/dereckscompany/defillama>.

## Licence

MIT © Dereck Mezquita
