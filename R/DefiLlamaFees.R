# File: R/DefiLlamaFees.R
# The fees/revenue client, on the main host (api.llama.fi). Structurally the twin of
# DefiLlamaVolumes -- DefiLlama's fees adapter shares the dimension-overview response
# shape with the DEX-volumes adapter -- but a distinct domain: the `data_type`
# selector switches the totals between fees paid, protocol revenue, and holders'
# revenue.

#' DefiLlamaFees: Protocol Fees and Revenue
#'
#' @description
#' Retrieves DefiLlama's fees/revenue overview: the per-protocol fees breakdown (one
#' row per protocol, with trailing 24h/7d/30d/1y/all-time totals) and the aggregate
#' daily fees time series, optionally scoped to a single chain. All keyless.
#'
#' @details
#' The `data_type` argument (one of [FEES_DATA_TYPES]) selects what the totals mean —
#' `dailyFees` (total fees paid by users), `dailyRevenue` (the protocol's share), or
#' `dailyHoldersRevenue` (the share flowing to token holders) — and is passed verbatim
#' to the DefiLlama `dataType` query parameter. The per-protocol `total*` columns are
#' measurements typed `| NA`.
#'
#' Inherits from [DefiLlamaBase]; all methods honour the `async` flag set at
#' construction (sync returns a `data.table`, async a promise).
#'
#' @examples
#' \dontrun{
#' fees <- DefiLlamaFees$new()
#' # Per-protocol fees breakdown across all chains:
#' fees$get_fees_overview()
#' # Protocol revenue (not total fees) on one chain:
#' fees$get_fees_overview(chain = "ethereum", data_type = "dailyRevenue")
#' # The aggregate daily fees history:
#' fees$get_fees_chart()
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
DefiLlamaFees <- R6::R6Class(
  "DefiLlamaFees",
  inherit = DefiLlamaBase,
  public = list(
    #' @description Initialise a DefiLlamaFees client.
    #' @param base_url (scalar<character>) the main API base URL. Defaults to
    #'   [defillama_base_url()].
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param max_tries (scalar<count in [1, Inf[>) retry budget for the idempotent
    #'   GET requests. Default `3`.
    #' @return (class<DefiLlamaFees>) invisibly, self.
    initialize = function(base_url = defillama_base_url(), async = FALSE, max_tries = 3L) {
      assert_args_DefiLlamaFees__initialize(base_url, async, max_tries)
      super$initialize(base_url = base_url, async = async, max_tries = max_tries)
      return(invisible(assert_return_DefiLlamaFees__initialize(self)))
    },

    #' @description The per-protocol fees breakdown: one row per protocol with its
    #'   trailing 24h/7d/30d/1y/all-time totals (fees or revenue per `data_type`).
    #'   Optionally scoped to a single chain.
    #' @param chain (scalar<character> | NULL) restrict to one chain, e.g.
    #'   `"ethereum"`; `NULL` (default) covers all chains.
    #' @param data_type (scalar<character>) the fees series to report, one of
    #'   [FEES_DATA_TYPES]. Default `"dailyFees"`.
    #' @return (DimensionOverview | promise<DimensionOverview>) one row per protocol,
    #'   or a promise thereof.
    get_fees_overview = function(chain = NULL, data_type = FEES_DATA_TYPES[["daily_fees"]]) {
      assert_args_DefiLlamaFees__get_fees_overview(chain, data_type)
      defillama_check_data_type(data_type, unlist(FEES_DATA_TYPES, use.names = FALSE))
      endpoint <- if (is.null(chain)) "/overview/fees" else paste0("/overview/fees/", chain)
      res <- private$.request(
        endpoint = endpoint,
        query = list(
          excludeTotalDataChart = "true",
          excludeTotalDataChartBreakdown = "true",
          dataType = data_type
        ),
        .parser = function(body) parse_dimension_overview(body, data_type)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaFees__get_fees_overview,
        is_async = private$.is_async
      ))
    },

    #' @description The aggregate daily fees time series (the overview's
    #'   `totalDataChart`), one row per UTC day. Optionally scoped to a single chain.
    #' @param chain (scalar<character> | NULL) restrict to one chain; `NULL` (default)
    #'   covers all chains.
    #' @param data_type (scalar<character>) the fees series to report, one of
    #'   [FEES_DATA_TYPES]. Default `"dailyFees"`.
    #' @return (DimensionChart | promise<DimensionChart>) one row per UTC day, or a
    #'   promise thereof.
    get_fees_chart = function(chain = NULL, data_type = FEES_DATA_TYPES[["daily_fees"]]) {
      assert_args_DefiLlamaFees__get_fees_chart(chain, data_type)
      defillama_check_data_type(data_type, unlist(FEES_DATA_TYPES, use.names = FALSE))
      endpoint <- if (is.null(chain)) "/overview/fees" else paste0("/overview/fees/", chain)
      res <- private$.request(
        endpoint = endpoint,
        query = list(
          excludeTotalDataChartBreakdown = "true",
          dataType = data_type
        ),
        .parser = function(body) parse_dimension_chart(body, data_type)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaFees__get_fees_chart,
        is_async = private$.is_async
      ))
    }
  )
)
