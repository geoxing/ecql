%%% Copyright (c) 2016 eMQTT.IO, All Rights Reserved.
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in all
%%% copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%%% SOFTWARE.
%%% 
%%% @author Feng Lee <feng@emqtt.io>
%%%

-module(ecql_tests).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

-define(OPTIONS, [{nodes, [{"127.0.0.1", 9042}]},
                  {keyspace, "test"},
                  {username, "cassandra"},
                  {password, "cassandra"}]).

ecql_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [fun tests/1]}.

setup() ->
    {ok, C} = ecql:connect(?OPTIONS), C.

tests(C) ->
    [?_test(t_use_keyspace(C)),
     ?_test(t_select(C)),
     ?_test(t_update(C)),
     ?_test(t_prepare(C)),
     ?_test(t_named_prepare(C))].

cleanup(C) ->
    ecql:close(C).

t_use_keyspace(C) ->
    {ok, <<"test">>} = ecql:query(C, "use test").

t_select(C) ->
    {ok, {<<"test.tab">>, _Columns, _Rows}} = ecql:query(C, "select * from test.tab"),
    {ok, Result} = ecql:query(C, "select * from test.tab where first_id = ? and second_id = ?", [{bigint, 1}, 'secid']),
    ?debugFmt("Result: ~p~n", [Result]).

t_update(C) ->
    ok = ecql:query(C, <<"update test.tab set col_map['keyx'] = 'valuex' where first_id = 1 and second_id = 'secid'">>),
    {ok, Ref} = ecql:async_query(C, "select col_text from test.tab"),
    receive
        {async_cql_reply, Ref, {ok, {<<"test.tab">>, [{<<"col_text">>, varchar}], Rows}}} ->
            ?debugFmt("AsyncQuery Rows: ~p~n", [Rows]);
        {async_cql_reply, Ref, Error} ->
            throw(Error)
    after
        1000 -> error(timeout)
    end.

t_prepare(C) ->
    {ok, Id} = ecql:prepare(C, "select * from test.tab where first_id = ? and second_id = ?"),
    {ok, {TableSpec, Columns, Rows}} = ecql:execute(C, Id, [{bigint, 1}, 'secid']).

t_named_prepare(C) ->
    {ok, _Id} = ecql:prepare(C, select_one, "select * from test.tab where first_id = ? limit 1"), 
    {ok, {TableSpec, Columns, Rows}} = ecql:execute(C, select_one, [{bigint, 1}]).

-endif.

