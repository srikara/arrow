# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#' Write Arrow IPC stream format
#'
#' Apache Arrow defines two formats for [serializing data for interprocess
#' communication (IPC)](https://arrow.apache.org/docs/format/Columnar.html#serialization-and-interprocess-communication-ipc):
#' a "stream" format and a "file" format, known as Feather. `write_ipc_stream()`
#' and [write_feather()] write those formats, respectively.
#'
#' `write_arrow()`, a wrapper around `write_ipc_stream()` and `write_feather()`
#' with some nonstandard behavior, is deprecated. You should explicitly choose
#' the function that will write the desired IPC format (stream or file) since
#' either can be written to a file or `OutputStream`.
#'
#' @inheritParams write_feather
#' @param ... extra parameters passed to `write_feather()`.
#'
#' @return `x`, invisibly.
#' @seealso [write_feather()] for writing IPC files. [write_to_raw()] to
#' serialize data to a buffer.
#' [RecordBatchWriter] for a lower-level interface.
#' @export
write_ipc_stream <- function(x, sink, ...) {
  x_out <- x # So we can return the data we got
  if (is.data.frame(x)) {
    x <- Table$create(x)
  }
  if (is.character(sink) && length(sink) == 1) {
    sink <- FileOutputStream$create(sink)
    on.exit(sink$close())
  }
  assert_is(sink, "OutputStream")

  writer <- RecordBatchStreamWriter$create(sink, x$schema)
  writer$write(x)
  writer$close()
  invisible(x_out)
}

#' Write Arrow data to a raw vector
#'
#' [write_ipc_stream()] and [write_feather()] write data to a sink and return
#' the data (`data.frame`, `RecordBatch`, or `Table`) they were given.
#' This function wraps those so that you can serialize data to a buffer and
#' access that buffer as a `raw` vector in R.
#' @inheritParams write_feather
#' @param format one of `c("stream", "file")`, indicating the IPC format to use
#' @return A `raw` vector containing the bytes of the IPC serialized data.
#' @export
write_to_raw <- function(x, format = c("stream", "file")) {
  sink <- BufferOutputStream$create()
  if (match.arg(format) == "stream") {
    write_ipc_stream(x, sink)
  } else {
    write_feather(x, sink)
  }
  as.raw(buffer(sink))
}

#' Read Arrow IPC stream format
#'
#' Apache Arrow defines two formats for [serializing data for interprocess
#' communication (IPC)](https://arrow.apache.org/docs/format/Columnar.html#serialization-and-interprocess-communication-ipc):
#' a "stream" format and a "file" format, known as Feather. `read_ipc_stream()`
#' and [read_feather()] read those formats, respectively.
#'
#' `read_arrow()`, a wrapper around `read_ipc_stream()` and `read_feather()`,
#' is deprecated. You should explicitly choose
#' the function that will read the desired IPC format (stream or file) since
#' a file or `InputStream` may contain either. `read_table()`, a wrapper around
#' `read_arrow()`, is also deprecated
#'
#' @param x A character file name, `raw` vector, or an Arrow input stream
#' @inheritParams read_delim_arrow
#' @param ... extra parameters passed to `read_feather()`.
#'
#' @return A `data.frame` if `as_data_frame` is `TRUE` (the default), or an
#' Arrow [Table] otherwise
#' @seealso [read_feather()] for writing IPC files. [RecordBatchReader] for a
#' lower-level interface.
#' @export
read_ipc_stream <- function(x, as_data_frame = TRUE, ...) {
  if (inherits(x, "raw")) {
    x <- BufferReader$create(x)
    on.exit(x$close())
  } else if (is.character(x) && length(x) == 1) {
    x <- ReadableFile$create(x)
    on.exit(x$close())
  }
  assert_is(x, "InputStream")

  # TODO: this could take col_select, like the other readers
  # https://issues.apache.org/jira/browse/ARROW-6830
  out <- RecordBatchStreamReader$create(x)$read_table()
  if (as_data_frame) {
    out <- as.data.frame(out)
  }
  out
}
