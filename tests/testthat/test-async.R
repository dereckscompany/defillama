# The async (promise) path must agree with the sync path. The connectcore mock
# harness intercepts req_perform AND req_perform_promise, so the SAME router serves
# both. is_async threads from the constructor through every method's then_or_now()
# tail; these prove a promise is returned and resolves to the same table the sync
# call returns, across both hosts.

box::use(./mock_router[.mock_routes])

resolve_promise <- function(p) {
  done <- FALSE
  val <- NULL
  err <- NULL
  promises::then(
    p,
    onFulfilled = function(v) {
      val <<- v
      done <<- TRUE
      return(invisible(NULL))
    },
    onRejected = function(e) {
      err <<- e
      done <<- TRUE
      return(invisible(NULL))
    }
  )
  for (i in seq_len(1000L)) {
    if (done) {
      break
    }
    later::run_now(timeout = 0.01)
  }
  if (!is.null(err)) {
    stop(err)
  }
  return(val)
}

test_that("get_stablecoin_charts async resolves to the sync table (stablecoins host)", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- DefiLlamaStablecoins$new(async = FALSE)$get_stablecoin_charts(stablecoin_id = 1)
  p <- DefiLlamaStablecoins$new(async = TRUE)$get_stablecoin_charts(stablecoin_id = 1)
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("get_protocols async resolves to the sync table (main host)", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- DefiLlamaProtocols$new(async = FALSE)$get_protocols()
  p <- DefiLlamaProtocols$new(async = TRUE)$get_protocols()
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("get_dexs_overview async resolves to the sync table", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- DefiLlamaVolumes$new(async = FALSE)$get_dexs_overview()
  p <- DefiLlamaVolumes$new(async = TRUE)$get_dexs_overview()
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("an async HTTP error rejects the promise with the typed condition", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  p <- DefiLlamaProtocols$new(async = TRUE, max_tries = 1L)$get_protocol("notaprotocol")
  expect_true(inherits(p, "promise"))
  err <- tryCatch(resolve_promise(p), error = function(e) e)
  expect_s3_class(err, "defillama_api_error_400")
})
