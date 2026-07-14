# File: R/helpers_parse.R
# The DefiLlama parse layer. Each endpoint's JSON (a bare array for the chart/list
# endpoints, an object wrapping an array for the stablecoins list and the dimension
# overviews) is flattened into one typed data.table with snake_case columns. Every
# parser's empty branch returns a fully-typed zero-row table via an `empty_dt_*()`
# constructor, so a caller's column contract holds on an empty result. The peg-nested
# measures (DefiLlama wraps each stablecoin amount under its peg-type key, e.g.
# `{"peggedUSD": 1.84e11}`) are unwrapped faithfully -- an ABSENT optional measure
# becomes NA, never 0, so a genuine zero and a missing value stay distinguishable.

# ---- Small coercers ----

#' Unwrap a peg-nested measure to its numeric value, or NA
#'
#' DefiLlama nests each stablecoin measure under its peg-type key, e.g.
#' `list(peggedUSD = 1.84e11)`. Pull the single value out regardless of the key name;
#' an absent measure (`NULL`) becomes `NA_real_` -- never 0, so a genuine zero and a
#' missing measure stay distinguishable.
#'
#' @param measure (list | NULL) the peg-nested measure object, or `NULL`.
#' @return (scalar<numeric | NA>) the unwrapped value, or `NA_real_`.
#' @keywords internal
#' @noassert
#' @noRd
peg_value <- function(measure) {
  value <- NA_real_
  if (!is.null(measure) && length(measure) > 0L) {
    value <- suppressWarnings(as.numeric(measure[[1L]]))
  }
  return(value)
}

#' The peg-type key of a peg-nested measure, or NA
#'
#' @param measure (list | NULL) the peg-nested measure object, e.g.
#'   `list(peggedUSD = ...)`, or `NULL`.
#' @return (scalar<character | NA>) the peg-type key (`"peggedUSD"`, ...), or
#'   `NA_character_` when the measure is absent.
#' @keywords internal
#' @noassert
#' @noRd
peg_type <- function(measure) {
  type <- NA_character_
  if (!is.null(measure) && length(measure) > 0L) {
    type <- as.character(names(measure)[[1L]])
  }
  return(type)
}

#' Join a JSON string array to a ";"-joined scalar, or NA
#'
#' DefiLlama's `chains` field is an array of chain names; flatten it to one
#' `;`-joined character scalar so the record stays one row with no list column.
#' Empty/absent becomes `NA_character_`. Recover the vector with
#' `strsplit(value, ";", fixed = TRUE)`.
#'
#' @param x (list | NULL) the JSON string array, or `NULL`.
#' @return (scalar<character | NA>) the ";"-joined names, or `NA_character_`.
#' @keywords internal
#' @noassert
#' @noRd
join_chains <- function(x) {
  out <- NA_character_
  if (!is.null(x) && length(x) > 0L) {
    out <- paste(vapply(x, as.character, character(1L)), collapse = ";")
  }
  return(out)
}

#' Convert unix-seconds timestamps to POSIXct (UTC), NA-safe and length-preserving
#'
#' @param seconds (numeric) unix-seconds timestamp(s); `NA` where absent.
#' @return (class<POSIXct>) the times in UTC (length matching `seconds`).
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noassert
#' @noRd
sec_to_datetime <- function(seconds) {
  return(lubridate::as_datetime(seconds, tz = "UTC"))
}

# ---- Stablecoins: list ----

#' The typed zero-row PeggedAssets table
#'
#' @return (PeggedAssets) a zero-row, fully-typed pegged-assets table.
#' @keywords internal
#' @noRd
empty_dt_pegged_assets <- function() {
  return(assert_return_empty_dt_pegged_assets(data.table::data.table(
    id = character(0L),
    name = character(0L),
    symbol = character(0L),
    gecko_id = character(0L),
    peg_type = character(0L),
    peg_mechanism = character(0L),
    price = numeric(0L),
    price_source = character(0L),
    circulating = numeric(0L),
    circulating_prev_day = numeric(0L),
    circulating_prev_week = numeric(0L),
    circulating_prev_month = numeric(0L),
    chains = character(0L)
  )))
}

#' Parse the `/stablecoins` object into the PeggedAssets shape
#'
#' @param parsed (list | NULL) the parsed `/stablecoins` object (with a
#'   `peggedAssets` array), or `NULL` for an empty body.
#' @return (PeggedAssets) one row per stablecoin.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_pegged_assets <- function(parsed) {
  result <- empty_dt_pegged_assets()
  assets <- NULL
  if (!is.null(parsed) && !is.null(parsed[["peggedAssets"]])) {
    assets <- parsed[["peggedAssets"]]
  }
  if (!is.null(assets) && length(assets) > 0L) {
    result <- data.table::data.table(
      id = vapply(assets, function(a) connectcore::chr_or_na(a[["id"]]), character(1L)),
      name = vapply(assets, function(a) connectcore::chr_or_na(a[["name"]]), character(1L)),
      symbol = vapply(assets, function(a) connectcore::chr_or_na(a[["symbol"]]), character(1L)),
      gecko_id = vapply(assets, function(a) connectcore::chr_or_na(a[["gecko_id"]]), character(1L)),
      peg_type = vapply(assets, function(a) connectcore::chr_or_na(a[["pegType"]]), character(1L)),
      peg_mechanism = vapply(assets, function(a) connectcore::chr_or_na(a[["pegMechanism"]]), character(1L)),
      price = vapply(assets, function(a) connectcore::num_or_na(a[["price"]]), numeric(1L)),
      price_source = vapply(assets, function(a) connectcore::chr_or_na(a[["priceSource"]]), character(1L)),
      circulating = vapply(assets, function(a) peg_value(a[["circulating"]]), numeric(1L)),
      circulating_prev_day = vapply(assets, function(a) peg_value(a[["circulatingPrevDay"]]), numeric(1L)),
      circulating_prev_week = vapply(assets, function(a) peg_value(a[["circulatingPrevWeek"]]), numeric(1L)),
      circulating_prev_month = vapply(assets, function(a) peg_value(a[["circulatingPrevMonth"]]), numeric(1L)),
      chains = vapply(assets, function(a) join_chains(a[["chains"]]), character(1L))
    )
  }
  return(result)
}

# ---- Stablecoins: charts ----

#' The typed zero-row StablecoinCharts table
#'
#' @return (StablecoinCharts) a zero-row, fully-typed stablecoin-charts table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_stablecoin_charts <- function() {
  return(assert_return_empty_dt_stablecoin_charts(data.table::data.table(
    stablecoin_id = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    peg_type = character(0L),
    total_circulating = numeric(0L),
    total_circulating_usd = numeric(0L),
    total_unreleased = numeric(0L),
    total_minted_usd = numeric(0L),
    total_bridged_to_usd = numeric(0L)
  )))
}

#' Parse a `/stablecoincharts` array into the StablecoinCharts shape
#'
#' The response is a bare array of daily records, each carrying a unix-seconds `date`
#' (string) plus the peg-nested measures. The optional measures (totalUnreleased /
#' totalMintedUSD / totalBridgedToUSD) are absent on most days; an absent measure
#' becomes NA (never 0).
#'
#' @param parsed (list | NULL) the parsed array, or `NULL` for an empty body.
#' @param stablecoin_id (scalar<character> | NULL) the queried pegged-asset id (a
#'   constant column), or `NULL` for the aggregate (recorded as NA).
#' @return (StablecoinCharts) one row per UTC day.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_stablecoin_charts <- function(parsed, stablecoin_id) {
  result <- empty_dt_stablecoin_charts()
  if (!is.null(parsed) && length(parsed) > 0L) {
    id_col <- if (is.null(stablecoin_id)) NA_character_ else as.character(stablecoin_id)
    result <- data.table::data.table(
      stablecoin_id = id_col,
      datetime = sec_to_datetime(vapply(parsed, function(d) connectcore::num_or_na(d[["date"]]), numeric(1L))),
      peg_type = vapply(parsed, function(d) peg_type(d[["totalCirculating"]]), character(1L)),
      total_circulating = vapply(parsed, function(d) peg_value(d[["totalCirculating"]]), numeric(1L)),
      total_circulating_usd = vapply(parsed, function(d) peg_value(d[["totalCirculatingUSD"]]), numeric(1L)),
      total_unreleased = vapply(parsed, function(d) peg_value(d[["totalUnreleased"]]), numeric(1L)),
      total_minted_usd = vapply(parsed, function(d) peg_value(d[["totalMintedUSD"]]), numeric(1L)),
      total_bridged_to_usd = vapply(parsed, function(d) peg_value(d[["totalBridgedToUSD"]]), numeric(1L))
    )
    data.table::setorderv(result, "datetime")
  }
  return(result)
}

# ---- Stablecoins: chains ----

#' The typed zero-row StablecoinChains table
#'
#' @return (StablecoinChains) a zero-row, fully-typed stablecoin-chains table.
#' @keywords internal
#' @noRd
empty_dt_stablecoin_chains <- function() {
  return(assert_return_empty_dt_stablecoin_chains(data.table::data.table(
    name = character(0L),
    peg_type = character(0L),
    total_circulating_usd = numeric(0L)
  )))
}

#' Parse a `/stablecoinchains` array into the StablecoinChains shape
#'
#' @param parsed (list | NULL) the parsed array, or `NULL` for an empty body.
#' @return (StablecoinChains) one row per chain.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_stablecoin_chains <- function(parsed) {
  result <- empty_dt_stablecoin_chains()
  if (!is.null(parsed) && length(parsed) > 0L) {
    result <- data.table::data.table(
      name = vapply(parsed, function(rec) connectcore::chr_or_na(rec[["name"]]), character(1L)),
      peg_type = vapply(parsed, function(rec) peg_type(rec[["totalCirculatingUSD"]]), character(1L)),
      total_circulating_usd = vapply(parsed, function(rec) peg_value(rec[["totalCirculatingUSD"]]), numeric(1L))
    )
  }
  return(result)
}

# ---- Protocols: list ----

#' The typed zero-row Protocols table
#'
#' @return (Protocols) a zero-row, fully-typed protocols table.
#' @keywords internal
#' @noRd
empty_dt_protocols <- function() {
  return(assert_return_empty_dt_protocols(data.table::data.table(
    id = character(0L),
    name = character(0L),
    symbol = character(0L),
    chain = character(0L),
    category = character(0L),
    chains = character(0L),
    url = character(0L),
    logo = character(0L),
    gecko_id = character(0L),
    cmc_id = character(0L),
    parent_protocol = character(0L),
    tvl = numeric(0L),
    change_1h = numeric(0L),
    change_1d = numeric(0L),
    change_7d = numeric(0L),
    mcap = numeric(0L),
    staking = numeric(0L),
    pool2 = numeric(0L)
  )))
}

#' Parse the `/protocols` array into the Protocols shape
#'
#' @param parsed (list | NULL) the parsed array, or `NULL` for an empty body.
#' @return (Protocols) one row per protocol.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_protocols <- function(parsed) {
  result <- empty_dt_protocols()
  if (!is.null(parsed) && length(parsed) > 0L) {
    result <- data.table::data.table(
      id = vapply(parsed, function(p) connectcore::chr_or_na(p[["id"]]), character(1L)),
      name = vapply(parsed, function(p) connectcore::chr_or_na(p[["name"]]), character(1L)),
      symbol = vapply(parsed, function(p) connectcore::chr_or_na(p[["symbol"]]), character(1L)),
      chain = vapply(parsed, function(p) connectcore::chr_or_na(p[["chain"]]), character(1L)),
      category = vapply(parsed, function(p) connectcore::chr_or_na(p[["category"]]), character(1L)),
      chains = vapply(parsed, function(p) join_chains(p[["chains"]]), character(1L)),
      url = vapply(parsed, function(p) connectcore::chr_or_na(p[["url"]]), character(1L)),
      logo = vapply(parsed, function(p) connectcore::chr_or_na(p[["logo"]]), character(1L)),
      gecko_id = vapply(parsed, function(p) connectcore::chr_or_na(p[["gecko_id"]]), character(1L)),
      cmc_id = vapply(parsed, function(p) connectcore::chr_or_na(p[["cmcId"]]), character(1L)),
      parent_protocol = vapply(parsed, function(p) connectcore::chr_or_na(p[["parentProtocol"]]), character(1L)),
      tvl = vapply(parsed, function(p) connectcore::num_or_na(p[["tvl"]]), numeric(1L)),
      change_1h = vapply(parsed, function(p) connectcore::num_or_na(p[["change_1h"]]), numeric(1L)),
      change_1d = vapply(parsed, function(p) connectcore::num_or_na(p[["change_1d"]]), numeric(1L)),
      change_7d = vapply(parsed, function(p) connectcore::num_or_na(p[["change_7d"]]), numeric(1L)),
      mcap = vapply(parsed, function(p) connectcore::num_or_na(p[["mcap"]]), numeric(1L)),
      staking = vapply(parsed, function(p) connectcore::num_or_na(p[["staking"]]), numeric(1L)),
      pool2 = vapply(parsed, function(p) connectcore::num_or_na(p[["pool2"]]), numeric(1L))
    )
  }
  return(result)
}

# ---- Protocols: single-protocol historical TVL ----

#' The typed zero-row ProtocolTvl table
#'
#' @return (ProtocolTvl) a zero-row, fully-typed protocol-TVL table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_protocol_tvl <- function() {
  return(assert_return_empty_dt_protocol_tvl(data.table::data.table(
    slug = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    tvl_usd = numeric(0L)
  )))
}

#' Parse a `/protocol/{slug}` object into the ProtocolTvl shape
#'
#' The response is a rich object; this extracts only its `tvl` array (one
#' `{date, totalLiquidityUSD}` per UTC day) into the tidy historical series.
#'
#' @param parsed (list | NULL) the parsed protocol object, or `NULL`.
#' @param slug (scalar<character>) the queried protocol slug (a constant column).
#' @return (ProtocolTvl) one row per UTC day.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_protocol_tvl <- function(parsed, slug) {
  result <- empty_dt_protocol_tvl()
  series <- NULL
  if (!is.null(parsed) && !is.null(parsed[["tvl"]])) {
    series <- parsed[["tvl"]]
  }
  if (!is.null(series) && length(series) > 0L) {
    result <- data.table::data.table(
      slug = as.character(slug),
      datetime = sec_to_datetime(vapply(series, function(d) connectcore::num_or_na(d[["date"]]), numeric(1L))),
      tvl_usd = vapply(series, function(d) connectcore::num_or_na(d[["totalLiquidityUSD"]]), numeric(1L))
    )
    data.table::setorderv(result, "datetime")
  }
  return(result)
}

# ---- Chains: current TVL ----

#' The typed zero-row ChainTvl table
#'
#' @return (ChainTvl) a zero-row, fully-typed chain-TVL table.
#' @keywords internal
#' @noRd
empty_dt_chain_tvl <- function() {
  return(assert_return_empty_dt_chain_tvl(data.table::data.table(
    name = character(0L),
    chain_id = character(0L),
    token_symbol = character(0L),
    gecko_id = character(0L),
    cmc_id = character(0L),
    tvl = numeric(0L)
  )))
}

#' Parse the `/v2/chains` array into the ChainTvl shape
#'
#' @param parsed (list | NULL) the parsed array, or `NULL`.
#' @return (ChainTvl) one row per chain.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_chain_tvl <- function(parsed) {
  result <- empty_dt_chain_tvl()
  if (!is.null(parsed) && length(parsed) > 0L) {
    result <- data.table::data.table(
      name = vapply(parsed, function(rec) connectcore::chr_or_na(rec[["name"]]), character(1L)),
      chain_id = vapply(parsed, function(rec) connectcore::chr_or_na(rec[["chainId"]]), character(1L)),
      token_symbol = vapply(parsed, function(rec) connectcore::chr_or_na(rec[["tokenSymbol"]]), character(1L)),
      gecko_id = vapply(parsed, function(rec) connectcore::chr_or_na(rec[["gecko_id"]]), character(1L)),
      cmc_id = vapply(parsed, function(rec) connectcore::chr_or_na(rec[["cmcId"]]), character(1L)),
      tvl = vapply(parsed, function(rec) connectcore::num_or_na(rec[["tvl"]]), numeric(1L))
    )
  }
  return(result)
}

# ---- Chains: historical TVL ----

#' The typed zero-row ChainTvlHistory table
#'
#' @return (ChainTvlHistory) a zero-row, fully-typed chain-TVL-history table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_chain_tvl_history <- function() {
  return(assert_return_empty_dt_chain_tvl_history(data.table::data.table(
    chain = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    tvl = numeric(0L)
  )))
}

#' Parse a `/v2/historicalChainTvl` array into the ChainTvlHistory shape
#'
#' @param parsed (list | NULL) the parsed array of `{date, tvl}`, or `NULL`.
#' @param chain (scalar<character> | NULL) the queried chain (a constant column), or
#'   `NULL` for the all-chains aggregate (recorded as NA).
#' @return (ChainTvlHistory) one row per UTC day.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_chain_tvl_history <- function(parsed, chain) {
  result <- empty_dt_chain_tvl_history()
  if (!is.null(parsed) && length(parsed) > 0L) {
    chain_col <- if (is.null(chain)) NA_character_ else as.character(chain)
    result <- data.table::data.table(
      chain = chain_col,
      datetime = sec_to_datetime(vapply(parsed, function(d) connectcore::num_or_na(d[["date"]]), numeric(1L))),
      tvl = vapply(parsed, function(d) connectcore::num_or_na(d[["tvl"]]), numeric(1L))
    )
    data.table::setorderv(result, "datetime")
  }
  return(result)
}

# ---- Dimension adapters (DEX volumes, fees): overview + chart ----

#' The typed zero-row DimensionOverview table
#'
#' @return (DimensionOverview) a zero-row, fully-typed dimension-overview table.
#' @keywords internal
#' @noRd
empty_dt_dimension_overview <- function() {
  return(assert_return_empty_dt_dimension_overview(data.table::data.table(
    data_type = character(0L),
    id = character(0L),
    name = character(0L),
    display_name = character(0L),
    module = character(0L),
    category = character(0L),
    protocol_type = character(0L),
    slug = character(0L),
    defillama_id = character(0L),
    logo = character(0L),
    chains = character(0L),
    parent_protocol = character(0L),
    total24h = numeric(0L),
    total7d = numeric(0L),
    total30d = numeric(0L),
    total1y = numeric(0L),
    total_all_time = numeric(0L),
    change_1d = numeric(0L),
    change_7d = numeric(0L),
    change_1m = numeric(0L)
  )))
}

#' Parse a `/overview/{dexs,fees}` object into the DimensionOverview shape
#'
#' Extracts the `protocols` array (one row per protocol) into the tidy overview.
#'
#' @param parsed (list | NULL) the parsed overview object, or `NULL`.
#' @param data_type (scalar<character>) the queried dataType (a constant column).
#' @return (DimensionOverview) one row per protocol.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_dimension_overview <- function(parsed, data_type) {
  result <- empty_dt_dimension_overview()
  protocols <- NULL
  if (!is.null(parsed) && !is.null(parsed[["protocols"]])) {
    protocols <- parsed[["protocols"]]
  }
  if (!is.null(protocols) && length(protocols) > 0L) {
    result <- data.table::data.table(
      data_type = as.character(data_type),
      id = vapply(protocols, function(p) connectcore::chr_or_na(p[["id"]]), character(1L)),
      name = vapply(protocols, function(p) connectcore::chr_or_na(p[["name"]]), character(1L)),
      display_name = vapply(protocols, function(p) connectcore::chr_or_na(p[["displayName"]]), character(1L)),
      module = vapply(protocols, function(p) connectcore::chr_or_na(p[["module"]]), character(1L)),
      category = vapply(protocols, function(p) connectcore::chr_or_na(p[["category"]]), character(1L)),
      protocol_type = vapply(protocols, function(p) connectcore::chr_or_na(p[["protocolType"]]), character(1L)),
      slug = vapply(protocols, function(p) connectcore::chr_or_na(p[["slug"]]), character(1L)),
      defillama_id = vapply(protocols, function(p) connectcore::chr_or_na(p[["defillamaId"]]), character(1L)),
      logo = vapply(protocols, function(p) connectcore::chr_or_na(p[["logo"]]), character(1L)),
      chains = vapply(protocols, function(p) join_chains(p[["chains"]]), character(1L)),
      parent_protocol = vapply(protocols, function(p) connectcore::chr_or_na(p[["parentProtocol"]]), character(1L)),
      total24h = vapply(protocols, function(p) connectcore::num_or_na(p[["total24h"]]), numeric(1L)),
      total7d = vapply(protocols, function(p) connectcore::num_or_na(p[["total7d"]]), numeric(1L)),
      total30d = vapply(protocols, function(p) connectcore::num_or_na(p[["total30d"]]), numeric(1L)),
      total1y = vapply(protocols, function(p) connectcore::num_or_na(p[["total1y"]]), numeric(1L)),
      total_all_time = vapply(protocols, function(p) connectcore::num_or_na(p[["totalAllTime"]]), numeric(1L)),
      change_1d = vapply(protocols, function(p) connectcore::num_or_na(p[["change_1d"]]), numeric(1L)),
      change_7d = vapply(protocols, function(p) connectcore::num_or_na(p[["change_7d"]]), numeric(1L)),
      change_1m = vapply(protocols, function(p) connectcore::num_or_na(p[["change_1m"]]), numeric(1L))
    )
  }
  return(result)
}

#' The typed zero-row DimensionChart table
#'
#' @return (DimensionChart) a zero-row, fully-typed dimension-chart table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_dimension_chart <- function() {
  return(assert_return_empty_dt_dimension_chart(data.table::data.table(
    data_type = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    value = numeric(0L)
  )))
}

#' Parse a `/overview/{dexs,fees}` object's `totalDataChart` into the DimensionChart shape
#'
#' The `totalDataChart` is an array of `[unix_seconds, value]` pairs (the aggregate
#' daily series); flatten each pair into a tidy `(datetime, value)` row.
#'
#' @param parsed (list | NULL) the parsed overview object (with a `totalDataChart`),
#'   or `NULL`.
#' @param data_type (scalar<character>) the queried dataType (a constant column).
#' @return (DimensionChart) one row per UTC day.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_dimension_chart <- function(parsed, data_type) {
  result <- empty_dt_dimension_chart()
  chart <- NULL
  if (!is.null(parsed) && !is.null(parsed[["totalDataChart"]])) {
    chart <- parsed[["totalDataChart"]]
  }
  if (!is.null(chart) && length(chart) > 0L) {
    result <- data.table::data.table(
      data_type = as.character(data_type),
      datetime = sec_to_datetime(vapply(chart, function(pt) connectcore::nth_num(pt, 1L), numeric(1L))),
      value = vapply(chart, function(pt) connectcore::nth_num(pt, 2L), numeric(1L))
    )
    data.table::setorderv(result, "datetime")
  }
  return(result)
}
