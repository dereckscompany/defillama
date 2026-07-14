# Guards the typed-empty invariant: every parser's empty branch must return a
# zero-row data.table that still carries its full typed column set (and no list
# column), never a column-less data.table() -- which would silently violate the
# methods' column @return contracts on an empty result.

fx <- connectcore::load_fixtures(test_path("fixtures"), parse = TRUE)

test_that("the typed-empty constructors return zero-row typed tables with no list columns", {
  empties <- list(
    pegged_assets = empty_dt_pegged_assets(),
    stablecoin_charts = empty_dt_stablecoin_charts(),
    stablecoin_chains = empty_dt_stablecoin_chains(),
    protocols = empty_dt_protocols(),
    protocol_tvl = empty_dt_protocol_tvl(),
    chain_tvl = empty_dt_chain_tvl(),
    chain_tvl_history = empty_dt_chain_tvl_history(),
    dimension_overview = empty_dt_dimension_overview(),
    dimension_chart = empty_dt_dimension_chart()
  )
  for (nm in names(empties)) {
    dt <- empties[[nm]]
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "columns"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})

test_that("every parser returns a typed zero-row empty on a NULL body", {
  cases <- list(
    pegged_assets = parse_pegged_assets(NULL),
    stablecoin_charts = parse_stablecoin_charts(NULL, stablecoin_id = 1),
    stablecoin_chains = parse_stablecoin_chains(NULL),
    protocols = parse_protocols(NULL),
    protocol_tvl = parse_protocol_tvl(NULL, slug = "aave"),
    chain_tvl = parse_chain_tvl(NULL),
    chain_tvl_history = parse_chain_tvl_history(NULL, chain = "Ethereum"),
    dimension_overview = parse_dimension_overview(NULL, data_type = "dailyVolume"),
    dimension_chart = parse_dimension_chart(NULL, data_type = "dailyVolume")
  )
  for (nm in names(cases)) {
    dt <- cases[[nm]]
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "columns"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})

test_that("empty and populated tables agree on column names and types (drift guard)", {
  pairs <- list(
    list(empty = empty_dt_pegged_assets(), full = parse_pegged_assets(fx$stablecoins)),
    list(empty = empty_dt_stablecoin_charts(), full = parse_stablecoin_charts(fx$stablecoin_charts, 1)),
    list(empty = empty_dt_stablecoin_chains(), full = parse_stablecoin_chains(fx$stablecoin_chains)),
    list(empty = empty_dt_protocols(), full = parse_protocols(fx$protocols)),
    list(empty = empty_dt_protocol_tvl(), full = parse_protocol_tvl(fx$protocol_tvl, "aave")),
    list(empty = empty_dt_chain_tvl(), full = parse_chain_tvl(fx$chains)),
    list(empty = empty_dt_chain_tvl_history(), full = parse_chain_tvl_history(fx$chain_tvl_history, "Ethereum")),
    list(empty = empty_dt_dimension_overview(), full = parse_dimension_overview(fx$dexs, "dailyVolume")),
    list(empty = empty_dt_dimension_chart(), full = parse_dimension_chart(fx$dexs, "dailyVolume"))
  )
  for (p in pairs) {
    expect_identical(names(p$full), names(p$empty))
    expect_identical(
      vapply(p$full, function(x) class(x)[1L], ""),
      vapply(p$empty, function(x) class(x)[1L], "")
    )
  }
})
