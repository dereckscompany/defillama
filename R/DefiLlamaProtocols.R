# File: R/DefiLlamaProtocols.R
# The protocol / chain TVL client, on the main host (api.llama.fi). Four read
# surfaces: the cross-sectional protocol list with current TVL, one protocol's full
# historical TVL, the current TVL per chain, and a chain's (or the whole DeFi
# ecosystem's) historical TVL.

#' DefiLlamaProtocols: DeFi Protocol and Chain Total Value Locked (TVL)
#'
#' @description
#' Retrieves DefiLlama's TVL data: the list of every tracked DeFi protocol with its
#' current TVL and identity, one protocol's full historical TVL, the current
#' aggregate TVL of every chain, and a chain's (or the whole ecosystem's) historical
#' TVL. All keyless.
#'
#' @details
#' The current-TVL `tvl` column and the historical series are measurements typed
#' `| NA`: DefiLlama legitimately reports no TVL for some protocols (e.g. a pure DEX
#' that has volume but no locked value), and omits the field rather than reporting 0.
#'
#' Inherits from [DefiLlamaBase]; all methods honour the `async` flag set at
#' construction (sync returns a `data.table`, async a promise).
#'
#' @examples
#' \dontrun{
#' tvl <- DefiLlamaProtocols$new()
#' # Every protocol with current TVL:
#' tvl$get_protocols()
#' # One protocol's full historical TVL:
#' tvl$get_protocol("aave")
#' # Current TVL per chain:
#' tvl$get_chains()
#' # Historical TVL of one chain (or omit for the whole DeFi aggregate):
#' tvl$get_historical_chain_tvl("Ethereum")
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
DefiLlamaProtocols <- R6::R6Class(
  "DefiLlamaProtocols",
  inherit = DefiLlamaBase,
  public = list(
    #' @description Initialise a DefiLlamaProtocols client.
    #' @param base_url (scalar<character>) the main API base URL. Defaults to
    #'   [defillama_base_url()].
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param max_tries (scalar<count in [1, Inf[>) retry budget for the idempotent
    #'   GET requests. Default `3`.
    #' @return (class<DefiLlamaProtocols>) invisibly, self.
    initialize = function(base_url = defillama_base_url(), async = FALSE, max_tries = 3L) {
      assert_args_DefiLlamaProtocols__initialize(base_url, async, max_tries)
      super$initialize(base_url = base_url, async = async, max_tries = max_tries)
      return(invisible(assert_return_DefiLlamaProtocols__initialize(self)))
    },

    #' @description List every tracked DeFi protocol with its current TVL and identity.
    #'   One row per protocol.
    #' @return (Protocols | promise<Protocols>) one row per protocol, or a promise
    #'   thereof.
    get_protocols = function() {
      res <- private$.request(
        endpoint = "/protocols",
        .parser = parse_protocols
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaProtocols__get_protocols,
        is_async = private$.is_async
      ))
    },

    #' @description The full historical TVL of one protocol, one row per UTC day.
    #'   Sourced from the rich `/protocol/{slug}` object (only its top-level `tvl`
    #'   series is surfaced).
    #' @param slug (scalar<character>) the protocol slug (from
    #'   `get_protocols()$slug`), e.g. `"aave"`.
    #' @return (ProtocolTvl | promise<ProtocolTvl>) one row per UTC day, or a promise
    #'   thereof.
    get_protocol = function(slug) {
      assert_args_DefiLlamaProtocols__get_protocol(slug)
      assert::assert_nonempty_strings(slug)
      res <- private$.request(
        endpoint = paste0("/protocol/", slug),
        .parser = function(body) parse_protocol_tvl(body, slug)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaProtocols__get_protocol,
        is_async = private$.is_async
      ))
    },

    #' @description The current aggregate DeFi TVL of every chain. One row per chain.
    #' @return (ChainTvl | promise<ChainTvl>) one row per chain, or a promise thereof.
    get_chains = function() {
      res <- private$.request(
        endpoint = "/v2/chains",
        .parser = parse_chain_tvl
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaProtocols__get_chains,
        is_async = private$.is_async
      ))
    },

    #' @description The historical aggregate TVL of one chain, or of the whole DeFi
    #'   ecosystem when no chain is given. One row per UTC day.
    #' @param chain (scalar<character> | NULL) the chain, e.g. `"Ethereum"`; `NULL`
    #'   (default) returns the all-chains DeFi aggregate.
    #' @return (ChainTvlHistory | promise<ChainTvlHistory>) one row per UTC day, or a
    #'   promise thereof.
    get_historical_chain_tvl = function(chain = NULL) {
      assert_args_DefiLlamaProtocols__get_historical_chain_tvl(chain)
      endpoint <- if (is.null(chain)) "/v2/historicalChainTvl" else paste0("/v2/historicalChainTvl/", chain)
      res <- private$.request(
        endpoint = endpoint,
        .parser = function(body) parse_chain_tvl_history(body, chain)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DefiLlamaProtocols__get_historical_chain_tvl,
        is_async = private$.is_async
      ))
    }
  )
)
