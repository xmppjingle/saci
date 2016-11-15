%% -*- coding: utf-8 -*-
%%
%% Copyright 2016 Nathan Fiedler. All rights reserved.
%% Use of this source code is governed by a BSD-style
%% license that can be found in the LICENSE file.
%%
-module(enenra_SUITE).
-compile(export_all).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-include("enenra.hrl").

init_per_suite(Config) ->
    % starting our app starts everything else that we need (e.g. hackney)
    {ok, _Started} = application:ensure_all_started(enenra),
    Config.

end_per_suite(_Config) ->
    case application:stop(enenra) of
        ok -> ok;
        {error, {not_started, enenra}} -> ok;
        {error, Reason} -> error(Reason)
    end.

all() ->
    [
        bucket_lifecycle_test
    ].

bucket_lifecycle_test(_Config) ->
    Credentials = get_env("GOOGLE_APPLICATION_CREDENTIALS"),
    {ok, Creds} = enenra:load_credentials(Credentials),

    %
    % create a new, uniquely named bucket
    %
    Suffix = integer_to_binary(crypto:rand_uniform(1, 9999)),
    Name = <<"0136d00f-a942-11e6-8f9a-3c07547e18a6-enenra-", Suffix/binary>>,
    Region = <<"US">>,
    StorageClass = <<"NEARLINE">>,
    InBucket = #bucket{
        name=Name,
        location=Region,
        class= StorageClass
    },
    {ok, OutBucket} = enenra:insert_bucket(InBucket, Creds),
    ?assertEqual(Name, OutBucket#bucket.name),
    ?assertEqual(Region, OutBucket#bucket.location),
    ?assertEqual(StorageClass, OutBucket#bucket.class),

    %
    % inserting a bucket should be idempotent and return the same record
    %
    {ok, OutBucket2} = enenra:insert_bucket(InBucket, Creds),
    ?assertEqual(OutBucket, OutBucket2),

    %
    % retrieve the bucket we just created
    %
    {ok, GetBucket} = enenra:get_bucket(Name, Creds),
    ?assertEqual(Name, GetBucket#bucket.name),
    ?assertEqual(Region, GetBucket#bucket.location),
    ?assertEqual(StorageClass, GetBucket#bucket.class),

    %
    % update the bucket by changing its storage class, which is pretty much
    % the only thing you _can_ change about a bucket
    %
    NewClass = <<"STANDARD">>,
    {ok, UpBucket} = enenra:update_bucket(Name, [{<<"storageClass">>, NewClass}], Creds),
    ?assertEqual(Name, UpBucket#bucket.name),
    ?assertEqual(Region, UpBucket#bucket.location),
    ?assertEqual(NewClass, UpBucket#bucket.class),

    %
    % ensure there is at least one bucket and that one of the buckets has
    % the name we expect
    %
    {ok, Buckets} = enenra:list_buckets(Creds),
    ?assert(is_list(Buckets)),
    ?assert(length(Buckets) > 1),
    ?assert(lists:any(fun (Elem) -> Elem#bucket.name == Name end, Buckets)),

    %
    % remove the bucket (note, this typically incurs an additional cost)
    %
    ok = enenra:delete_bucket(Name, Creds),
    {error, not_found} = enenra:delete_bucket(Name, Creds),
    ok.

% Retrieve an environment variable, ensuring it is defined.
get_env(Name) ->
    case os:getenv(Name) of
        false ->
            error(lists:flatten(io_lib:format("must define ~p environment variable", [Name])));
        Value -> Value
    end.
