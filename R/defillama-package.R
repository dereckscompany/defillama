# File: R/defillama-package.R
# Package-level documentation and shared imports.

#' defillama: API Wrapper to the DefiLlama API
#'
#' A keyless connector for the DefiLlama public API, built on the shared
#' [connectcore::RestClient] transport base. It returns tidy
#' [data.table::data.table]s and speaks DefiLlama's peg-nested amount format
#' faithfully.
#'
#' ### What is covered in this version
#' - [DefiLlamaStablecoins]: the stablecoins domain (stablecoins.llama.fi) — the
#'   cross-sectional list, the full daily circulating-supply history, and the current
#'   market cap per chain.
#' - [DefiLlamaProtocols]: protocol and chain TVL (api.llama.fi) — the protocol list,
#'   one protocol's historical TVL, current per-chain TVL, and historical chain TVL.
#' - [DefiLlamaVolumes]: DEX trading volumes — the per-DEX overview and the aggregate
#'   daily volume series.
#' - [DefiLlamaFees]: protocol fees and revenue — the per-protocol overview and the
#'   aggregate daily fees series.
#'
#' ### Sync and async
#' Every request-making surface supports both a synchronous mode (returns a
#' `data.table`) and an asynchronous mode (returns a [promises::promise] resolving to
#' the same `data.table`), selected by the `async` argument. See [DefiLlamaBase] for
#' the shared mechanism.
#'
#' ### No API key
#' DefiLlama's public endpoints are keyless, so no credential is ever required or
#' read.
#'
#' @keywords internal
#' @import data.table
#' @import assert
"_PACKAGE"

# Quiet R CMD check's "no visible binding" notes for the data.table columns
# referenced by name in the parsers' setorderv() calls.
utils::globalVariables(c(
  "datetime"
))
