import gleam/dynamic.{type Dynamic}
import gleam/http.{Delete, Get, Head, Options, Patch, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response, Response}
import gleam/option
import gleam/result
import nerf/gun.{type ConnectionOpts, type ConnectionPid}

pub type HttpError {
  ConnectionFailed(Dynamic)
  RequestFailed(Dynamic)
}

/// Send an HTTP request and return the response.
/// The connection is automatically closed after receiving the response.
pub fn send(req: Request(BitArray)) -> Result(Response(BitArray), HttpError) {
  let opts = case req.scheme {
    http.Http -> gun.default_tcp_opts()
    http.Https -> gun.default_tls_opts()
  }
  send_with_opts(req, opts)
}

/// Send an HTTP request with a string body.
pub fn send_string(req: Request(String)) -> Result(Response(BitArray), HttpError) {
  req
  |> request.map(fn(body) { <<body:utf8>> })
  |> send
}

/// Send an HTTP request with custom connection options.
/// Use this when you need to override the default HTTP/2+HTTP/1.1 behavior.
pub fn send_with_opts(
  req: Request(BitArray),
  opts: ConnectionOpts,
) -> Result(Response(BitArray), HttpError) {
  let port = option.unwrap(req.port, case req.scheme {
    http.Http -> 80
    http.Https -> 443
  })

  use pid <- result.try(
    gun.open_with_opts(req.host, port, opts)
    |> result.map_error(ConnectionFailed),
  )
  use _ <- result.try(
    gun.await_up(pid)
    |> result.map_error(ConnectionFailed),
  )

  let result = do_request(pid, req)
  gun.shutdown(pid)

  result
}

/// Send an HTTP request with a string body and custom connection options.
pub fn send_string_with_opts(
  req: Request(String),
  opts: ConnectionOpts,
) -> Result(Response(BitArray), HttpError) {
  req
  |> request.map(fn(body) { <<body:utf8>> })
  |> send_with_opts(opts)
}

fn do_request(
  pid: ConnectionPid,
  req: Request(BitArray),
) -> Result(Response(BitArray), HttpError) {
  let path = case req.query {
    option.Some(query) -> req.path <> "?" <> query
    option.None -> req.path
  }
  let path = case path {
    "" -> "/"
    _ -> path
  }

  let ref = case req.method {
    Get -> gun.get(pid, path, req.headers)
    Post -> gun.post(pid, path, req.headers, req.body)
    Put -> gun.put(pid, path, req.headers, req.body)
    Delete -> gun.delete(pid, path, req.headers)
    Patch -> gun.patch(pid, path, req.headers, req.body)
    Head -> gun.head(pid, path, req.headers)
    Options -> gun.options(pid, path, req.headers)
    _ -> gun.get(pid, path, req.headers)
  }

  case gun.await_response(pid, ref, 30_000) {
    Ok(#(status, headers, body)) ->
      Ok(Response(status: status, headers: headers, body: body))
    Error(reason) ->
      Error(RequestFailed(reason))
  }
}
