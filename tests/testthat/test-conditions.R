# The typed condition family: the two roots and their nesting, the structured
# fields, and the end-to-end surfacing of DefiLlama's HTTP errors through the
# envelope.

box::use(./mock_router[.mock_routes])

test_that("abort_defillama_error nests defillama -> connectcore -> root with fields", {
  err <- tryCatch(
    abort_defillama_error(status = 400L, url = "https://api.llama.fi/protocol/x", body = "boom", message = "bad"),
    error = function(e) e
  )
  expect_s3_class(err, "defillama_api_error_400")
  expect_s3_class(err, "defillama_api_error")
  expect_s3_class(err, "connectcore_api_error_400")
  expect_s3_class(err, "connectcore_api_error")
  expect_s3_class(err, "connectcore_error")
  expect_identical(err$status, 400L)
  expect_identical(err$body_snippet, "boom")
  expect_true(grepl("api.llama.fi", err$url, fixed = TRUE))
})

test_that("abort_defillama_validation_error nests under the domain root only", {
  err <- tryCatch(abort_defillama_validation_error("nope", field = "data_type"), error = function(e) e)
  expect_s3_class(err, "defillama_validation_error")
  expect_s3_class(err, "defillama_error")
  expect_false(inherits(err, "connectcore_error")) # domain root never meets the transport root
  expect_identical(err[["field"]], "data_type")
})

test_that("an unknown protocol slug surfaces as defillama_api_error_400 (end-to-end)", {
  connectcore::local_mock_api(.mock_routes)
  tvl <- DefiLlamaProtocols$new(max_tries = 1L)
  err <- tryCatch(tvl$get_protocol("notaprotocol"), error = function(e) e)
  expect_s3_class(err, "defillama_api_error_400")
  expect_identical(err$status, 400L)
})

test_that("an unknown dimension chain surfaces as defillama_api_error_500 (end-to-end)", {
  connectcore::local_mock_api(.mock_routes)
  vol <- DefiLlamaVolumes$new(max_tries = 1L)
  err <- tryCatch(vol$get_dexs_overview(chain = "badchain"), error = function(e) e)
  expect_s3_class(err, "defillama_api_error_500")
  expect_identical(err$status, 500L)
})
