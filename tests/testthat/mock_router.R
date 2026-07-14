# Shared mock HTTP router for the defillama README and tests.
#
# The THIN defillama-specific layer over connectcore's shared mock harness
# (connectcore::mock_router / with_mock_api / local_mock_api / load_fixtures /
# mock_response). connectcore owns the response builder, the dispatch loop, and the
# scoped-activation helpers; this file only declares the route table (URL pattern ->
# fixture) and loads the fixtures from disk.
#
# Every fixture is FULLY SYNTHETIC authored JSON (never captured from the live API),
# shaped exactly per the documented DefiLlama formats. The data fixtures carry
# representative multi-record bodies that exercise the `| NA` contract: a stablecoin
# with null gecko_id/price, an early chart day with the optional supply measures
# ABSENT beside a full day carrying a genuine ZERO, a multi-chain protocol with an
# absent `chain` and a null `tvl`, and a dimension-overview protocol with only its
# all-time total.

box::use(
  connectcore[load_fixtures]
)

# Load every synthetic fixture as its raw JSON string, keyed by file basename
# (protocols.json -> "protocols"). Resolved relative to THIS module file so it works
# from the package root (README) and tests/testthat alike.
.fixtures <- load_fixtures(box::file("fixtures"))

# DefiLlama answers an unknown protocol slug with an HTTP 400 text/plain
# "Protocol not found", an unknown dimension chain with an HTTP 500, and an unknown
# stablecoin id with an empty HTTP 200. These thunks reproduce those surfaces so the
# envelope's error/empty handling is exercised end-to-end.
#' @export
.protocol_not_found_response <- function() {
  return(httr2::response(
    status_code = 400L,
    url = "https://api.llama.fi/protocol/notaprotocol",
    headers = list("content-type" = "text/plain"),
    body = charToRaw("Protocol not found")
  ))
}

#' @export
.server_error_response <- function() {
  return(httr2::response(
    status_code = 500L,
    url = "https://api.llama.fi/overview/dexs/badchain",
    headers = list("content-type" = "text/plain"),
    body = charToRaw("Internal server error")
  ))
}

#' @export
.empty_response <- function() {
  return(httr2::response(
    status_code = 200L,
    url = "https://stablecoins.llama.fi/stablecoincharts/all?stablecoin=999999",
    headers = list("content-type" = "application/json"),
    body = charToRaw("")
  ))
}

#' Route table: URL pattern -> synthetic-fixture JSON string (or a response thunk).
#'
#' Order matters -- the more specific routes precede the general ones (the bad-id /
#' bad-slug / bad-chain error routes before their family route, and the single
#' `/protocol/{slug}` before the `/protocols` list).
#' @export
.mock_routes <- list(
  # ---- Stablecoins host (stablecoins.llama.fi) ----
  list(pattern = "stablecoin=999999", fixture = .empty_response),
  list(pattern = "/stablecoincharts", fixture = .fixtures$stablecoin_charts),
  list(pattern = "/stablecoinchains", fixture = .fixtures$stablecoin_chains),
  list(pattern = "/stablecoins?includePrices", fixture = .fixtures$stablecoins),

  # ---- Protocols / chains (api.llama.fi) ----
  list(pattern = "/protocol/notaprotocol", fixture = .protocol_not_found_response),
  list(pattern = "/protocol/", fixture = .fixtures$protocol_tvl),
  list(pattern = "/protocols", fixture = .fixtures$protocols),
  list(pattern = "/v2/historicalChainTvl", fixture = .fixtures$chain_tvl_history),
  list(pattern = "/v2/chains", fixture = .fixtures$chains),

  # ---- Dimension adapters (api.llama.fi) ----
  list(pattern = "/overview/dexs/badchain", fixture = .server_error_response),
  list(pattern = "/overview/dexs", fixture = .fixtures$dexs),
  list(pattern = "/overview/fees", fixture = .fixtures$fees)
)
