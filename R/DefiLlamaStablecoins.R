# File: R/DefiLlamaStablecoins.R
# The stablecoins client. DefiLlama serves the stablecoins domain from its own host
# (stablecoins.llama.fi), so this class defaults its base_url to that host. Three
# read surfaces: the current cross-sectional list, the full daily circulating-supply
# history (the collector's dogfood endpoint), and the current market cap per chain.

#' DefiLlamaStablecoins: Stablecoin Circulating Supply and Market Cap
#'
#' @description
#' Retrieves DefiLlama's stablecoins data: the cross-sectional list of every tracked
#' stablecoin with its current circulating supply and price, the full daily
#' circulating-supply history of one stablecoin (or the aggregate of all), and the
#' current stablecoin market cap per chain. All keyless.
#'
#' @details
#' DefiLlama nests each supply measure under its **peg type** key (e.g.
#' `{"peggedUSD": 1.84e11}`); this client unwraps the value faithfully and records
#' the peg type in a `peg_type` column. The optional history measures
#' (`total_unreleased`, `total_minted_usd`, `total_bridged_to_usd`) are present on
#' only a minority of days — an absent measure is `NA`, never `0`, so a genuine zero
#' and a missing value stay distinguishable.
#'
#' Inherits from [DefiLlamaBase]; all methods honour the `async` flag set at
#' construction (sync returns a `data.table`, async a promise).
#'
#' @examples
#' \dontrun{
#' sc <- DefiLlamaStablecoins$new()
#' # Every tracked stablecoin, current supply and price:
#' sc$get_stablecoins()
#' # The full daily history of Tether (pegged-asset id 1):
#' sc$get_stablecoin_charts(stablecoin_id = 1)
#' # The aggregate history across all stablecoins:
#' sc$get_stablecoin_charts()
#' # Current stablecoin market cap by chain:
#' sc$get_stablecoin_chains()
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
DefiLlamaStablecoins <- R6::R6Class(
  "DefiLlamaStablecoins",
  inherit = DefiLlamaBase,
  public = list(
    #' @description Initialise a DefiLlamaStablecoins client.
    #' @param base_url (scalar<character>) the stablecoins API base URL. Defaults to
    #'   [defillama_stablecoins_url()].
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param max_tries (scalar<count in [1, Inf[>) retry budget for the idempotent
    #'   GET requests. Default `3`.
    #' @return (class<DefiLlamaStablecoins>) invisibly, self.
    initialize = function(base_url = defillama_stablecoins_url(), async = FALSE, max_tries = 3L) {
      assert_args_DefiLlamaStablecoins__initialize(base_url, async, max_tries)
      super$initialize(base_url = base_url, async = async, max_tries = max_tries)
      return(invisible(assert_return_DefiLlamaStablecoins__initialize(self)))
    },

    #' @description List every tracked stablecoin with its current circulating supply
    #'   and (optionally) price. One row per stablecoin.
    #' @param include_prices (scalar<logical>) request the latest price of each
    #'   stablecoin (the `includePrices` query flag). Default `TRUE`; `FALSE` leaves
    #'   the `price` column `NA`.
    #' @return (PeggedAssets | promise<PeggedAssets>) one row per stablecoin, or a
    #'   promise thereof.
    get_stablecoins = function(include_prices = TRUE) {
      assert_args_DefiLlamaStablecoins__get_stablecoins(include_prices)
      res <- private$.request(
        endpoint = "/stablecoins",
        query = list(includePrices = tolower(as.character(include_prices))),
        .parser = parse_pegged_assets
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaStablecoins__get_stablecoins,
        is_async = private$.is_async
      ))
    },

    #' @description The full daily circulating-supply and USD-market-cap history of
    #'   one stablecoin (by pegged-asset id), or the aggregate of all stablecoins when
    #'   no id is given. Optionally scoped to a single chain. The whole history comes
    #'   in one call (no pagination). One row per UTC day.
    #' @param stablecoin_id (scalar<character> | scalar<count in [1, Inf[> | NULL) the
    #'   DefiLlama pegged-asset id (from `get_stablecoins()$id`), e.g. `1` for Tether;
    #'   `NULL` (default) returns the all-stablecoins aggregate.
    #' @param chain (scalar<character> | NULL) restrict to one chain, e.g.
    #'   `"Ethereum"`; `NULL` (default) aggregates across all chains.
    #' @return (StablecoinCharts | promise<StablecoinCharts>) one row per UTC day, or a
    #'   promise thereof.
    get_stablecoin_charts = function(stablecoin_id = NULL, chain = NULL) {
      assert_args_DefiLlamaStablecoins__get_stablecoin_charts(stablecoin_id, chain)
      endpoint <- if (is.null(chain)) "/stablecoincharts/all" else paste0("/stablecoincharts/", chain)
      res <- private$.request(
        endpoint = endpoint,
        query = list(stablecoin = stablecoin_id),
        .parser = function(body) parse_stablecoin_charts(body, stablecoin_id)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaStablecoins__get_stablecoin_charts,
        is_async = private$.is_async
      ))
    },

    #' @description The current total stablecoin market cap on each chain. One row per
    #'   chain.
    #' @return (StablecoinChains | promise<StablecoinChains>) one row per chain, or a
    #'   promise thereof.
    get_stablecoin_chains = function() {
      res <- private$.request(
        endpoint = "/stablecoinchains",
        .parser = parse_stablecoin_chains
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaStablecoins__get_stablecoin_chains,
        is_async = private$.is_async
      ))
    }
  )
)
