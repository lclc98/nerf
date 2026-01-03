-module(nerf_ffi).

-export([ws_receive/2, ws_await_upgrade/2, ws_send_erl/3, make_tls_opts/0, make_tcp_opts/0, await_response/3]).

ws_receive({connection, Ref, Pid}, Timeout)
    when is_reference(Ref) andalso is_pid(Pid) ->
    receive
        {gun_ws, Pid, Ref, close} -> {ok, close};
        {gun_ws, Pid, Ref, {close, _}} -> {ok, close};
        {gun_ws, Pid, Ref, {close, _, _}} -> {ok, close};
        {gun_ws, Pid, Ref, {text, _} = Frame} -> {ok, Frame};
        {gun_ws, Pid, Ref, {binary, _} = Frame} -> {ok, Frame}
    after Timeout ->
      {error, nil}
    end.

ws_await_upgrade({connection, Ref, Pid}, Timeout) 
    when is_reference(Ref) andalso is_pid(Pid) ->
    receive
        %% Success case
        {gun_upgrade, Pid, Ref, [<<"websocket">>], _} ->
            {ok, nil};
        
        %% Server rejected upgrade (e.g., 404, 403, etc.)
        {gun_response, Pid, _, _, Status, Headers} ->
            {error, {ws_upgrade_failed, Status, Headers}};
        
        %% Gun couldn't perform upgrade (e.g., HTTP/1.0 connection, network error)
        {gun_error, Pid, Ref, Reason} ->
            {error, {ws_upgrade_failed, Reason}};
        
        %% Connection went down during upgrade
        {gun_down, Pid, _Protocol, Reason, _KilledStreams} ->
            {error, {connection_down, Reason}};
        
        %% Gun process died
        {'DOWN', _MRef, process, Pid, Reason} ->
            {error, {process_down, Reason}}
    after Timeout ->
        {error, timeout}
    end.

ws_send_erl(Pid, Ref, {text_builder, Text}) ->
    ws_send_erl(Pid, Ref, {text, Text});
ws_send_erl(Pid, Ref, {binary_builder, Bin}) ->
    ws_send_erl(Pid, Ref, {binary, Bin});
ws_send_erl(Pid, Ref, Frame) ->
    gun:ws_send(Pid, Ref, Frame).

make_tls_opts() ->
    #{
        transport => tls,
        protocols => [http],
        tls_opts => [
            {verify, verify_none}
        ]
    }.

make_tcp_opts() ->
    #{
        transport => tcp,
        protocols => [http]
    }.

await_response(Pid, Ref, Timeout) ->
    case gun:await(Pid, Ref, Timeout) of
        {response, fin, Status, Headers} ->
            {ok, {Status, Headers, <<>>}};
        {response, nofin, Status, Headers} ->
            case gun:await_body(Pid, Ref, Timeout) of
                {ok, Body} ->
                    {ok, {Status, Headers, Body}};
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.