# File: R/DefiLlamaBase.R
# Abstract R6 base class for the DefiLlama API client classes. Inherits the generic
# transport (sync/async funnel, retry, throttle) from connectcore::RestClient and
# plugs in the one DefiLlama-specific seam: the response envelope (.parse_envelope).
# DefiLlama is a KEYLESS public API, so there is no signing seam -- the base leaves
# connectcore's no-auth default in place. DefiLlama splits its surface across two
# hosts (api.llama.fi and stablecoins.llama.fi), but no single client hits both, so
# each subclass simply sets its own base_url default; the base needs no per-request
# host override (unlike the dual-host coinbase base).

#' DefiLlamaBase: Abstract Base Class for DefiLlama API Clients
#'
#' @description
#' The shared base every DefiLlama R6 client extends. It provides the transport
#' plumbing (the single sync/async request funnel, retry, throttle) by inheriting
#' [connectcore::RestClient], and customises only the one seam specific to the
#' DefiLlama API.
#'
#' @details
#' DefiLlama is a **keyless** public JSON API, so this base overrides just the
#' envelope seam and leaves authentication as connectcore's no-auth default:
#' - `.parse_envelope()` — the DefiLlama error/empty-body envelope (via the internal
#'   `parse_defillama_response()`): it raises a typed [defillama_conditions] error on
#'   a non-2xx status, treats an empty 2xx body as "no data" (`NULL`, which each
#'   parser turns into a typed zero-row table), and otherwise parses the JSON.
#'
#' ### Sync vs async
#' The `async` argument selects the execution mode for every method:
#' - `async = FALSE` (default): methods return a [data.table::data.table].
#' - `async = TRUE`: methods return a [promises::promise] that resolves to the same
#'   `data.table`.
#'
#' The mode is stored once as `private$.is_async` and threaded through every method's
#' `connectcore::then_or_now(res, ..., is_async = private$.is_async)` tail; nothing
#' hardcodes it. Consume promises with [coro::async()] and `await()`; drive the loop
#' in a script with `while (!later::loop_empty()) later::run_now()`.
#'
#' ### Hosts
#' DefiLlama splits its surface across two hosts: the main host
#' ([defillama_base_url()], `https://api.llama.fi`) serves protocols, TVL, DEX
#' volumes, and fees; the stablecoins host ([defillama_stablecoins_url()],
#' `https://stablecoins.llama.fi`) serves the stablecoins domain. Each subclass sets
#' the correct host as its `base_url` default, so a client only ever speaks to one
#' host.
#'
#' ### Retries
#' `max_tries > 1` opts every request (all are idempotent GETs) into automatic retry
#' on a transient failure (HTTP 408/429/5xx or a dropped connection) with jittered
#' backoff, delegated to [connectcore::build_request()]. DefiLlama's public endpoints
#' are read-only, so retrying is always safe. Default `3` (a modest retry budget for
#' a free public feed).
#'
#' This class is not meant to be instantiated directly; subclasses (e.g.
#' [DefiLlamaStablecoins], [DefiLlamaProtocols], [DefiLlamaVolumes], [DefiLlamaFees])
#' define the public methods.
#'
#' @importFrom R6 R6Class
#' @export
DefiLlamaBase <- R6::R6Class(
  "DefiLlamaBase",
  inherit = connectcore::RestClient,
  public = list(
    #' @description Initialise a DefiLlamaBase object.
    #' @param base_url (scalar<character>) the API base URL for this client (its
    #'   host).
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param max_tries (scalar<count in [1, Inf[>) for the idempotent GET requests
    #'   this client makes, retry up to this many times on a transient failure.
    #'   Default `3`.
    #' @return (class<DefiLlamaBase>) invisibly, self.
    initialize = function(base_url, async = FALSE, max_tries = 3L) {
      assert_args_DefiLlamaBase__initialize(base_url, async, max_tries)
      assert::assert_nonempty_strings(base_url)
      super$initialize(
        keys = NULL,
        base_url = base_url,
        async = async,
        body_format = "none",
        user_agent = "dereckscompany/defillama",
        max_tries = max_tries
      )
      return(invisible(assert_return_DefiLlamaBase__initialize(self)))
    }
  ),
  private = list(
    # The DefiLlama error/empty-body envelope; DefiLlama is keyless, so the sign
    # seam keeps connectcore's no-auth default.
    .parse_envelope = function(resp) {
      return(parse_defillama_response(resp))
    }
  )
)
