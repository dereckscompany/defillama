# File: R/DefiLlamaVolumes.R
# The DEX-volumes client, on the main host (api.llama.fi). DefiLlama's dimension
# adapters expose one "overview" endpoint that returns BOTH a per-protocol breakdown
# and an aggregate daily time series; this client splits them into two typed tables
# (one method -> one data.table): the overview rows and the aggregate chart. The
# `data_type` selector chooses the volume series (dailyVolume / totalVolume).

#' DefiLlamaVolumes: Decentralized-Exchange Trading Volumes
#'
#' @description
#' Retrieves DefiLlama's DEX-volumes overview: the per-DEX volume breakdown (one row
#' per protocol, with trailing 24h/7d/30d/1y/all-time totals) and the aggregate daily
#' volume time series, optionally scoped to a single chain. All keyless.
#'
#' @details
#' The `data_type` argument (one of [DEX_DATA_TYPES]) selects which volume series the
#' totals report; it is passed verbatim to the DefiLlama `dataType` query parameter.
#' The per-protocol `total*` columns are measurements typed `| NA` — a total is absent
#' until the protocol has that much history.
#'
#' Inherits from [DefiLlamaBase]; all methods honour the `async` flag set at
#' construction (sync returns a `data.table`, async a promise).
#'
#' @examples
#' \dontrun{
#' vol <- DefiLlamaVolumes$new()
#' # Per-DEX volume breakdown across all chains:
#' vol$get_dexs_overview()
#' # Scoped to one chain:
#' vol$get_dexs_overview(chain = "ethereum")
#' # The aggregate daily DEX-volume history:
#' vol$get_dexs_chart()
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
DefiLlamaVolumes <- R6::R6Class(
  "DefiLlamaVolumes",
  inherit = DefiLlamaBase,
  public = list(
    #' @description Initialise a DefiLlamaVolumes client.
    #' @param base_url (scalar<character>) the main API base URL. Defaults to
    #'   [defillama_base_url()].
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param max_tries (scalar<count in [1, Inf[>) retry budget for the idempotent
    #'   GET requests. Default `3`.
    #' @return (class<DefiLlamaVolumes>) invisibly, self.
    initialize = function(base_url = defillama_base_url(), async = FALSE, max_tries = 3L) {
      assert_args_DefiLlamaVolumes__initialize(base_url, async, max_tries)
      super$initialize(base_url = base_url, async = async, max_tries = max_tries)
      return(invisible(assert_return_DefiLlamaVolumes__initialize(self)))
    },

    #' @description The per-DEX volume breakdown: one row per protocol with its
    #'   trailing 24h/7d/30d/1y/all-time volume totals. Optionally scoped to a single
    #'   chain.
    #' @param chain (scalar<character> | NULL) restrict to one chain, e.g.
    #'   `"ethereum"`; `NULL` (default) covers all chains.
    #' @param data_type (scalar<character>) the volume series to report, one of
    #'   [DEX_DATA_TYPES]. Default `"dailyVolume"`.
    #' @return (DimensionOverview | promise<DimensionOverview>) one row per DEX, or a
    #'   promise thereof.
    get_dexs_overview = function(chain = NULL, data_type = DEX_DATA_TYPES[["daily_volume"]]) {
      assert_args_DefiLlamaVolumes__get_dexs_overview(chain, data_type)
      defillama_check_data_type(data_type, unlist(DEX_DATA_TYPES, use.names = FALSE))
      endpoint <- if (is.null(chain)) "/overview/dexs" else paste0("/overview/dexs/", chain)
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
        assert_return_DefiLlamaVolumes__get_dexs_overview,
        is_async = private$.is_async
      ))
    },

    #' @description The aggregate daily DEX-volume time series (the overview's
    #'   `totalDataChart`), one row per UTC day. Optionally scoped to a single chain.
    #' @param chain (scalar<character> | NULL) restrict to one chain; `NULL` (default)
    #'   covers all chains.
    #' @param data_type (scalar<character>) the volume series to report, one of
    #'   [DEX_DATA_TYPES]. Default `"dailyVolume"`.
    #' @return (DimensionChart | promise<DimensionChart>) one row per UTC day, or a
    #'   promise thereof.
    get_dexs_chart = function(chain = NULL, data_type = DEX_DATA_TYPES[["daily_volume"]]) {
      assert_args_DefiLlamaVolumes__get_dexs_chart(chain, data_type)
      defillama_check_data_type(data_type, unlist(DEX_DATA_TYPES, use.names = FALSE))
      endpoint <- if (is.null(chain)) "/overview/dexs" else paste0("/overview/dexs/", chain)
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
        assert_return_DefiLlamaVolumes__get_dexs_chart,
        is_async = private$.is_async
      ))
    }
  )
)
