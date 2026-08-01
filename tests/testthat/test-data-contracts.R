test_that("negative survey codes become missing", {
  expect_true(all(is.na(clean_numeric(c(-9, -8, -7, -1)))))
  expect_equal(clean_numeric(c(0, 1, 2)), c(0, 1, 2))
})

test_that("hour and minute fields combine without inventing unknown minutes", {
  result <- combine_duration_hours(
    hours_raw = c(2, 0, 0, -9),
    minutes_raw = c(NA, 30, -9, 15)
  )
  expect_equal(result[1:2], c(2, 0.5))
  expect_true(all(is.na(result[3:4])))
})

test_that("effective sample size is bounded by row count", {
  weights <- c(1, 2, 3, 4)
  expect_gt(effective_n(weights), 0)
  expect_lte(effective_n(weights), length(weights))
})

test_that("weighted AUC handles perfect ranking and ties", {
  expect_equal(weighted_auc(c(0, 1), c(0.1, 0.9), c(1, 3)), 1)
  expect_equal(weighted_auc(c(0, 1), c(0.5, 0.5), c(1, 3)), 0.5)
})
