import gleam/bit_array
import gleam/bytes_tree
import gleam/http
import gleam/http/request
import gleam/result
import gleam/string
import gleam/string_tree
import gleeunit
import nerf/http as nerf_http
import nerf/websocket.{Binary, Text}

pub fn main() {
  gleeunit.main()
}

pub fn echo_test() {
  // Connect
  let assert Ok(conn) = websocket.connect("localhost", "/ws", 8080, [])

  // The server we're using sends a little hello message
  let assert Ok(Text(msg)) = websocket.receive(conn, 500)
  let assert True = string.starts_with(msg, "Request served by ")
  // Send some messages, the test server echos them back
  websocket.send(conn, "Hello")
  websocket.send(conn, "World")
  let assert Ok(Text("Hello")) = websocket.receive(conn, 500)
  let assert Ok(Text("World")) = websocket.receive(conn, 500)

  websocket.send_builder(conn, string_tree.from_string("Goodbye"))
  websocket.send_builder(conn, string_tree.from_string("Universe"))
  let assert Ok(Text("Goodbye")) = websocket.receive(conn, 500)
  let assert Ok(Text("Universe")) = websocket.receive(conn, 500)

  websocket.send_binary(conn, <<1, 2, 3, 4>>)
  websocket.send_binary(conn, <<5, 6, 7, 8>>)
  let assert Ok(Binary(<<1, 2, 3, 4>>)) = websocket.receive(conn, 500)
  let assert Ok(Binary(<<5, 6, 7, 8>>)) = websocket.receive(conn, 500)

  websocket.send_binary_builder(conn, bytes_tree.from_bit_array(<<8, 7, 6, 5>>))
  websocket.send_binary_builder(conn, bytes_tree.from_bit_array(<<4, 3, 2, 1>>))
  let assert Ok(Binary(<<8, 7, 6, 5>>)) = websocket.receive(conn, 500)
  let assert Ok(Binary(<<4, 3, 2, 1>>)) = websocket.receive(conn, 500)

  // Close the connection
  websocket.close(conn)
}

pub fn echo_wss_test() {
  // Connect
  let assert Ok(conn1) =
    websocket.connect_secure("echo.websocket.org", "/", 443, [])
  let _ = websocket.receive(conn1, 500)

  websocket.send(conn1, "Hello")
  let assert Ok(Text("Hello")) = websocket.receive(conn1, 500)

  // Close the connection
  websocket.close(conn1)
}

// HTTP Tests

pub fn http_get_test() {
  let assert Ok(req) = request.to("https://httpbin.org/get")
  let assert Ok(resp) = nerf_http.send_string(req)
  let assert 200 = resp.status
  let assert Ok(body) = bit_array.to_string(resp.body)
  let assert True = string.contains(body, "\"url\"")
}

pub fn http_post_test() {
  let assert Ok(req) =
    request.to("https://httpbin.org/post")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, "{\"test\": \"data\"}"))
    |> result.map(request.set_header(_, "content-type", "application/json"))
  let assert Ok(resp) = nerf_http.send_string(req)
  let assert 200 = resp.status
  let assert Ok(body) = bit_array.to_string(resp.body)
  let assert True = string.contains(body, "\"test\"")
}

pub fn http_put_test() {
  let assert Ok(req) =
    request.to("https://httpbin.org/put")
    |> result.map(request.set_method(_, http.Put))
    |> result.map(request.set_body(_, "put data"))
  let assert Ok(resp) = nerf_http.send_string(req)
  let assert 200 = resp.status
}

pub fn http_delete_test() {
  let assert Ok(req) =
    request.to("https://httpbin.org/delete")
    |> result.map(request.set_method(_, http.Delete))
  let assert Ok(resp) = nerf_http.send_string(req)
  let assert 200 = resp.status
}

pub fn http_patch_test() {
  let assert Ok(req) =
    request.to("https://httpbin.org/patch")
    |> result.map(request.set_method(_, http.Patch))
    |> result.map(request.set_body(_, "patch data"))
  let assert Ok(resp) = nerf_http.send_string(req)
  let assert 200 = resp.status
}

pub fn http_status_code_test() {
  let assert Ok(req) = request.to("https://httpbin.org/status/404")
  let assert Ok(resp) = nerf_http.send_string(req)
  let assert 404 = resp.status
}
