import gleam/bytes_tree.{type BytesTree}
import gleam/dynamic.{type Dynamic}
import gleam/http.{type Header}
import gleam/result
import gleam/string_tree
import nerf/gun.{
  type ConnectionPid, type StreamReference, type Transport, Tcp, Tls,
}

pub opaque type Connection {
  Connection(ref: StreamReference, pid: ConnectionPid)
}

pub type Frame {
  Close
  Text(String)
  Binary(BitArray)
}

/// Connect to a websocket server using plain TCP (ws://).
pub fn connect(
  hostname: String,
  path: String,
  on port: Int,
  with headers: List(Header),
) -> Result(Connection, ConnectError) {
  do_connect(hostname, path, port, headers, Tcp)
}

/// Connect to a websocket server using TLS (wss://).
pub fn connect_secure(
  hostname: String,
  path: String,
  on port: Int,
  with headers: List(Header),
) -> Result(Connection, ConnectError) {
  do_connect(hostname, path, port, headers, Tls)
}

fn do_connect(
  hostname: String,
  path: String,
  port: Int,
  headers: List(Header),
  transport: Transport,
) -> Result(Connection, ConnectError) {
  use pid <- result.try(
    gun.open_ws(hostname, port, transport)
    |> result.map_error(ConnectionFailed),
  )
  use _ <- result.try(
    gun.await_up(pid)
    |> result.map_error(ConnectionFailed),
  )

  // Upgrade to websockets
  let ref = gun.ws_upgrade(pid, path, headers)
  let conn = Connection(pid: pid, ref: ref)
  use _ <- result.try(
    await_upgrade(conn, 1000)
    |> result.map_error(ConnectionFailed),
  )

  // TODO: handle upgrade failure
  // https://ninenines.eu/docs/en/gun/2.0/guide/websocket/
  // https://ninenines.eu/docs/en/gun/1.2/manual/gun_error/
  // https://ninenines.eu/docs/en/gun/1.2/manual/gun_response/
  Ok(conn)
}

pub fn send(to conn: Connection, this message: String) -> Nil {
  gun.ws_send(conn.pid, conn.ref, gun.Text(message))
}

pub fn send_builder(
  to conn: Connection,
  this message: string_tree.StringTree,
) -> Nil {
  gun.ws_send(conn.pid, conn.ref, gun.TextBuilder(message))
}

pub fn send_binary(to conn: Connection, this message: BitArray) -> Nil {
  gun.ws_send(conn.pid, conn.ref, gun.Binary(message))
}

pub fn send_binary_builder(to conn: Connection, this message: BytesTree) -> Nil {
  gun.ws_send(conn.pid, conn.ref, gun.BinaryBuilder(message))
}

@external(erlang, "nerf_ffi", "ws_receive")
pub fn receive(from: Connection, within: Int) -> Result(Frame, Nil)

@external(erlang, "nerf_ffi", "ws_await_upgrade")
fn await_upgrade(from: Connection, within: Int) -> Result(Nil, Dynamic)

// TODO: listen for close events
pub fn close(conn: Connection) -> Nil {
  gun.ws_send(conn.pid, conn.ref, gun.Close)
}

/// The URI of the websocket server to connect to
pub type ConnectError {
  ConnectionRefused(status: Int, headers: List(Header))
  ConnectionFailed(reason: Dynamic)
}
