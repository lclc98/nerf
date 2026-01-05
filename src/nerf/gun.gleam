//// Low level bindings to the gun API. You typically do not need to use this.
//// Prefer the other modules in this library.

import gleam/bytes_tree.{type BytesTree}
import gleam/dynamic.{type Dynamic}
import gleam/erlang/charlist.{type Charlist}
import gleam/http.{type Header}
import gleam/string_tree.{type StringTree}

pub type StreamReference

pub type ConnectionPid

pub type ConnectionOpts

pub type Transport {
  Tcp
  Tls
}

pub fn open(host: String, port: Int, transport: Transport) -> Result(ConnectionPid, Dynamic) {
  let opts = case transport {
    Tcp -> make_tcp_opts()
    Tls -> make_tls_opts()
  }
  open_erl(charlist.from_string(host), port, opts)
}

@external(erlang, "gun", "open")
pub fn open_erl(host: Charlist, port: Int, opts: ConnectionOpts) -> Result(ConnectionPid, Dynamic)

/// Open a connection with custom options
pub fn open_with_opts(host: String, port: Int, opts: ConnectionOpts) -> Result(ConnectionPid, Dynamic) {
  open_erl(charlist.from_string(host), port, opts)
}

@external(erlang, "nerf_ffi", "make_tls_opts")
fn make_tls_opts() -> ConnectionOpts

@external(erlang, "nerf_ffi", "make_tcp_opts")
fn make_tcp_opts() -> ConnectionOpts

/// Default TLS options (HTTP/2 with HTTP/1.1 fallback)
@external(erlang, "nerf_ffi", "make_tls_opts")
pub fn default_tls_opts() -> ConnectionOpts

/// Default TCP options (HTTP/2 with HTTP/1.1 fallback)
@external(erlang, "nerf_ffi", "make_tcp_opts")
pub fn default_tcp_opts() -> ConnectionOpts

/// TLS options for HTTP/1.1 only
@external(erlang, "nerf_ffi", "make_ws_tls_opts")
pub fn http1_tls_opts() -> ConnectionOpts

/// TCP options for HTTP/1.1 only
@external(erlang, "nerf_ffi", "make_ws_tcp_opts")
pub fn http1_tcp_opts() -> ConnectionOpts

/// Open a connection for WebSocket (HTTP/1.1 only, required for WS upgrade)
pub fn open_ws(host: String, port: Int, transport: Transport) -> Result(ConnectionPid, Dynamic) {
  let opts = case transport {
    Tcp -> make_ws_tcp_opts()
    Tls -> make_ws_tls_opts()
  }
  open_erl(charlist.from_string(host), port, opts)
}

@external(erlang, "nerf_ffi", "make_ws_tls_opts")
fn make_ws_tls_opts() -> ConnectionOpts

@external(erlang, "nerf_ffi", "make_ws_tcp_opts")
fn make_ws_tcp_opts() -> ConnectionOpts

@external(erlang, "gun", "await_up")
pub fn await_up(pid: ConnectionPid) -> Result(Dynamic, Dynamic)

@external(erlang, "gun", "ws_upgrade")
pub fn ws_upgrade(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
) -> StreamReference

pub type Frame {
  Close
  Text(String)
  Binary(BitArray)
  TextBuilder(StringTree)
  BinaryBuilder(BytesTree)
}

type OkAtom

@external(erlang, "nerf_ffi", "ws_send_erl")
fn ws_send_erl(pid: ConnectionPid, ref: StreamReference, frame: Frame) -> OkAtom

pub fn ws_send(pid: ConnectionPid, ref: StreamReference, frame: Frame) -> Nil {
  ws_send_erl(pid, ref, frame)
  Nil
}

// HTTP request functions

@external(erlang, "gun", "get")
pub fn get(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
) -> StreamReference

@external(erlang, "gun", "post")
pub fn post(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
  body: BitArray,
) -> StreamReference

@external(erlang, "gun", "put")
pub fn put(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
  body: BitArray,
) -> StreamReference

@external(erlang, "gun", "delete")
pub fn delete(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
) -> StreamReference

@external(erlang, "gun", "patch")
pub fn patch(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
  body: BitArray,
) -> StreamReference

@external(erlang, "gun", "head")
pub fn head(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
) -> StreamReference

@external(erlang, "gun", "options")
pub fn options(
  pid: ConnectionPid,
  path: String,
  headers: List(Header),
) -> StreamReference

@external(erlang, "nerf_ffi", "await_response")
pub fn await_response(
  pid: ConnectionPid,
  ref: StreamReference,
  timeout: Int,
) -> Result(#(Int, List(Header), BitArray), Dynamic)

@external(erlang, "gun", "shutdown")
pub fn shutdown(pid: ConnectionPid) -> Nil
