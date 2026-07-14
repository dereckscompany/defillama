# File: R/constants.R
# Package constants and the environment-backed URL getters. No bare constants are
# hoisted at the top of other module files; every vocabulary value lives here with
# roxygen documentation, per the house convention. DefiLlama is keyless, so there
# is no credential getter -- only the two public hosts and the dimension-adapter
# data-type vocabularies.

#' DefiLlama main API base URL (`api.llama.fi`)
#'
#' The host serving protocols, TVL, DEX volumes, and fees/revenue (e.g.
#' `/protocols`, `/v2/chains`, `/overview/dexs`, `/overview/fees`). Overridable
#' with the `DEFILLAMA_BASE_URL` environment variable.
#'
#' @param url (scalar<character>) an explicit base URL override. Defaults to the
#'   `DEFILLAMA_BASE_URL` environment variable, or the public host when unset.
#' @return (scalar<character>) the base URL.
#' @export
defillama_base_url <- connectcore::url_getter("DEFILLAMA_BASE_URL", "https://api.llama.fi")

#' DefiLlama stablecoins API base URL (`stablecoins.llama.fi`)
#'
#' The separate host serving the stablecoins domain (e.g. `/stablecoins`,
#' `/stablecoincharts/all`, `/stablecoinchains`). DefiLlama splits the stablecoins
#' endpoints onto their own host, so `DefiLlamaStablecoins` addresses this base
#' while every other client addresses [defillama_base_url()]. Overridable with the
#' `DEFILLAMA_STABLECOINS_URL` environment variable.
#'
#' @param url (scalar<character>) an explicit base URL override. Defaults to the
#'   `DEFILLAMA_STABLECOINS_URL` environment variable, or the public host when
#'   unset.
#' @return (scalar<character>) the base URL.
#' @export
defillama_stablecoins_url <- connectcore::url_getter("DEFILLAMA_STABLECOINS_URL", "https://stablecoins.llama.fi")

#' DEX-volume `dataType` vocabulary
#'
#' The accepted values of the `data_type` argument of
#' `DefiLlamaVolumes$get_dexs_overview()` / `$get_dexs_chart()`, passed verbatim to
#' the DefiLlama `/overview/dexs` `dataType` query parameter. The name is the
#' snake_case handle; the value is the venue's own camelCase token (the faithful
#' wire vocabulary). `dailyVolume` is the traded-volume series; `totalVolume` is the
#' cumulative series.
#'
#' @format A named `list` of `scalar<character>` wire values: `dailyVolume`,
#'   `totalVolume`.
#' @export
DEX_DATA_TYPES <- list(
  daily_volume = "dailyVolume",
  total_volume = "totalVolume"
)

#' Fees/revenue `dataType` vocabulary
#'
#' The accepted values of the `data_type` argument of
#' `DefiLlamaFees$get_fees_overview()` / `$get_fees_chart()`, passed verbatim to the
#' DefiLlama `/overview/fees` `dataType` query parameter. The name is the snake_case
#' handle; the value is the venue's own camelCase token (the faithful wire
#' vocabulary). The `total*` columns of the returned table change meaning with this
#' selector: `dailyFees` is total fees paid by users, `dailyRevenue` the share kept
#' by the protocol, `dailyHoldersRevenue` the share flowing to token holders.
#'
#' @format A named `list` of `scalar<character>` wire values: `dailyFees`,
#'   `dailyRevenue`, `dailyHoldersRevenue`.
#' @export
FEES_DATA_TYPES <- list(
  daily_fees = "dailyFees",
  daily_revenue = "dailyRevenue",
  daily_holders_revenue = "dailyHoldersRevenue"
)
