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

@external(erlang, "nerf_ffi", "make_tls_opts")
fn make_tls_opts() -> ConnectionOpts

@external(erlang, "nerf_ffi", "make_tcp_opts")
fn make_tcp_opts() -> ConnectionOpts

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
