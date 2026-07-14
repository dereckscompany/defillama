# File: R/types_defillama.R
# Reusable roxyassert `@type` shapes for the data.tables the public surface returns.
# Each request-making method documents its return as one of these named shapes via
# `(Shape | promise<Shape>)`; the contract roclet expands the shape into that
# method's generated `assert_return_*` helper, so every column's presence and type is
# enforced at the public boundary -- for both the synchronous value and the resolved
# value of a promise (wired through `connectcore::then_or_now()`). The parsers in
# R/helpers_parse.R build the same shapes and their empty branches return the
# fully-typed zero-row table (`empty_dt_*()`), so a shape's column contract holds even
# on an empty result.
#
# FAITHFULNESS: DefiLlama omits optional fields freely -- an early-history stablecoin
# day carries none of the optional supply measures, most protocols carry no `tvl`,
# and a DEX's `total7d` is present only once it has a week of history. So every
# MEASUREMENT column (a circulating amount, a TVL, a volume, a fee total, a
# percentage change) is typed `| NA` and grounded from populated multi-record samples
# (never a single live record); an ABSENT measure becomes NA, never 0, so a genuine
# zero and a missing value stay distinguishable. STRUCTURAL columns (ids, names,
# symbols, period timestamps) are strict.

#' @title defillama return shapes
#' @description Reusable roxyassert `@type` shapes for the parsed defillama
#' `data.table`s. Measurement columns are typed `| NA`; structural columns are
#' strict. `defillama` is a leaf connector: nothing internal calls a per-shape
#' validator and no downstream package validates against these shapes, so there is no
#' `@genassert` and no `@exportassert`; the shapes exist only to be expanded into each
#' method's own return contract.
#' @name defillama_shapes
#'
#' @type PeggedAssets (data.table) one row per stablecoin, with its current circulating supply and price:
#' - id (character) the DefiLlama pegged-asset id, e.g. "1" for Tether; structural.
#' - name (character) the stablecoin name, e.g. "Tether"; structural.
#' - symbol (character) the ticker, e.g. "USDT"; structural.
#' - gecko_id (character | NA) the CoinGecko id; NA when DefiLlama has no mapping.
#' - peg_type (character) the peg the amounts are denominated in, e.g. "peggedUSD"; structural.
#' - peg_mechanism (character) the peg mechanism, e.g. "fiat-backed", "crypto-backed", "algorithmic"; structural.
#' - price (numeric | NA) the latest price of one unit; NA when unpriced or when includePrices is off.
#' - price_source (character | NA) the price source, e.g. "defillama"; NA when absent.
#' - circulating (numeric | NA) the current circulating amount, in peg units; measurement.
#' - circulating_prev_day (numeric | NA) the circulating amount one day ago, in peg units; measurement.
#' - circulating_prev_week (numeric | NA) the circulating amount one week ago, in peg units; measurement.
#' - circulating_prev_month (numeric | NA) the circulating amount one month ago, in peg units; measurement.
#' - chains (character | NA) the chains the stablecoin is deployed on, ";"-joined; NA when none listed.
#'
#' @type StablecoinCharts (data.table) one row per UTC day of a stablecoin's circulating-supply history:
#' - stablecoin_id (character | NA) the queried pegged-asset id; NA for the all-stablecoins aggregate (no id filter).
#' - datetime (POSIXct) the UTC day the record covers, from the unix-seconds date; structural.
#' - peg_type (character | NA) the peg key the amounts nest under, e.g. "peggedUSD"; NA on a day with no data.
#' - total_circulating (numeric | NA) the circulating amount that day, in peg units; measurement.
#' - total_circulating_usd (numeric | NA) the circulating amount that day, in USD; measurement.
#' - total_unreleased (numeric | NA) the unreleased (minted-but-not-circulating) amount; NA on days DefiLlama omits it.
#' - total_minted_usd (numeric | NA) total minted in USD; NA on the many days DefiLlama omits it (few carry it).
#' - total_bridged_to_usd (numeric | NA) the total bridged-in in USD; NA on the many days DefiLlama omits it.
#'
#' @type StablecoinChains (data.table) one row per chain, with its total stablecoin market cap:
#' - name (character) the chain name, e.g. "Ethereum"; structural.
#' - peg_type (character | NA) the peg key the amount is nested under, e.g. "peggedUSD"; NA when absent.
#' - total_circulating_usd (numeric | NA) the total stablecoin circulating on the chain, in USD; measurement.
#'
#' @type Protocols (data.table) one row per DeFi protocol, with its current TVL and identity (from `/protocols`):
#' - id (character) the DefiLlama protocol id; structural.
#' - name (character) the protocol name, e.g. "AAVE V3"; structural.
#' - symbol (character) the governance-token ticker, or "-" when none; structural.
#' - chain (character | NA) the single primary chain; NA for a multi-chain protocol (see chains).
#' - category (character) the protocol category, e.g. "Lending", "Dexes"; structural.
#' - chains (character | NA) every chain the protocol spans, ";"-joined; NA when none listed.
#' - url (character) the protocol's website; structural.
#' - logo (character) the logo URL; structural.
#' - gecko_id (character | NA) the CoinGecko id; NA when unmapped.
#' - cmc_id (character | NA) the CoinMarketCap id; NA when unmapped.
#' - parent_protocol (character | NA) the parent-protocol id when this is a sub-protocol; NA otherwise.
#' - tvl (numeric | NA) the current total value locked, in USD; NA for a protocol with no TVL (e.g. a pure DEX).
#' - change_1h (numeric | NA) the 1-hour TVL change, percent; measurement.
#' - change_1d (numeric | NA) the 1-day TVL change, percent; measurement.
#' - change_7d (numeric | NA) the 7-day TVL change, percent; measurement.
#' - mcap (numeric | NA) the token market cap, in USD; measurement.
#' - staking (numeric | NA) the value staked in the protocol's own token, in USD; measurement.
#' - pool2 (numeric | NA) the value in pool2 (LP) incentives, in USD; measurement.
#'
#' @type ProtocolTvl (data.table) one row per UTC day of a single protocol's historical TVL (from `/protocol/{slug}`):
#' - slug (character) the queried protocol slug, a constant column so the table is self-describing; structural.
#' - datetime (POSIXct) the UTC day, from the unix-seconds date; structural.
#' - tvl_usd (numeric | NA) the total value locked that day, in USD (the venue field totalLiquidityUSD); measurement.
#'
#' @type ChainTvl (data.table) one row per chain, with its current aggregate DeFi TVL (from `/v2/chains`):
#' - name (character) the chain name, e.g. "Ethereum"; structural.
#' - chain_id (character | NA) the chain's numeric id as a string; NA when DefiLlama has none.
#' - token_symbol (character | NA) the chain's native-token symbol, e.g. "ETH"; NA when absent.
#' - gecko_id (character | NA) the native token's CoinGecko id; NA when absent.
#' - cmc_id (character | NA) the native token's CoinMarketCap id; NA when absent.
#' - tvl (numeric | NA) the chain's current aggregate TVL, in USD; measurement.
#'
#' @type ChainTvlHistory (data.table) one row per UTC day of historical chain TVL (from `/v2/historicalChainTvl`):
#' - chain (character | NA) the queried chain, a constant column; NA for the all-chains DeFi aggregate.
#' - datetime (POSIXct) the UTC day, from the unix-seconds date; structural.
#' - tvl (numeric | NA) the aggregate TVL that day, in USD; measurement.
#'
#' @type DimensionOverview (data.table) one row per protocol of a DEX-volume or fees/revenue overview:
#' - data_type (character) the queried dataType, e.g. "dailyVolume" or "dailyFees", a constant column recording what the
#'   total_* columns mean; structural.
#' - id (character) the DefiLlama protocol id; structural.
#' - name (character) the protocol name; structural.
#' - display_name (character) the display name shown in the DefiLlama UI; structural.
#' - module (character) the DefiLlama adapter module name; structural.
#' - category (character) the protocol category, e.g. "Dexs", "Lending"; structural.
#' - protocol_type (character) the protocol type, e.g. "protocol", "chain"; structural.
#' - slug (character) the protocol slug; structural.
#' - defillama_id (character) the DefiLlama id used by the dimension adapter; structural.
#' - logo (character) the logo URL; structural.
#' - chains (character | NA) the chains the protocol spans, ";"-joined; NA when none listed.
#' - parent_protocol (character | NA) the parent-protocol id when this is a sub-protocol; NA otherwise.
#' - total24h (numeric | NA) the trailing-24h total (volume or fees per data_type), in USD; measurement.
#' - total7d (numeric | NA) the trailing-7-day total, in USD; NA before the protocol has a week of history.
#' - total30d (numeric | NA) the trailing-30-day total, in USD; measurement.
#' - total1y (numeric | NA) the trailing-1-year total, in USD; measurement.
#' - total_all_time (numeric | NA) the all-time cumulative total, in USD; measurement.
#' - change_1d (numeric | NA) the 1-day change, percent; measurement.
#' - change_7d (numeric | NA) the 7-day change, percent; measurement.
#' - change_1m (numeric | NA) the 1-month change, percent; measurement.
#'
#' @type DimensionChart (data.table) one row per UTC day of an aggregate DEX-volume or fees/revenue series:
#' - data_type (character) the queried dataType, e.g. "dailyVolume" or "dailyFees"; a constant column; structural.
#' - datetime (POSIXct) the UTC day, from the unix-seconds timestamp; structural.
#' - value (numeric | NA) the aggregate total that day (volume or fees per data_type), in USD; measurement.
NULL
