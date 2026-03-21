-module(emqx_plugin_kafka).

-include_lib("emqx/include/logger.hrl").
-include("emqx_plugin_kafka.hrl").

-export([
    load/0
    , unload/0
]).

load() ->
    load(read_config()).

load(Conf = #{connection := _, producer := _, hooks := _}) ->
    ?SLOG(info, #{
        msg => "emqx_plugin_kafka_load_start",
        hooks_count => length(maps:get(hooks, Conf, []))
    }),
    case validate_hooks(Conf) of
        ok ->
            emqx_plugin_kafka_util:check_crc32cer_nif(),
            case start_resource(Conf) of
                {ok, _} ->
                    hooks(Conf);
                error ->
                    {error, start_resource_failed}
            end;
        {error, _} = Error ->
            ?SLOG(error, #{
                msg => "emqx_plugin_kafka_invalid_config",
                reason => Error
            }),
            Error
    end;
load(_) ->
    {error, "config_error"}.

read_config() ->
    case hocon:load(kafka_config_file()) of
        {ok, RawConf} ->
            case emqx_config:check_config(emqx_plugin_kafka_schema, RawConf) of
                {_, #{plugin_kafka := Conf}} ->
                    ?SLOG(info, #{
                        msg => "emqx_plugin_kafka_config_loaded",
                        file => kafka_config_file(),
                        hooks_count => length(maps:get(hooks, Conf, []))
                    }),
                    Conf;
                _ ->
                    ?SLOG(error, #{
                        msg => "bad_hocon_file",
                        file => kafka_config_file()
                    }),
                    {error, bad_hocon_file}

            end;
        {error, Error} ->
            ?SLOG(error, #{
                msg => "bad_hocon_file",
                file => kafka_config_file(),
                reason => Error
            }),
            {error, bad_hocon_file}
    end.

kafka_config_file() ->
    Env = os:getenv("EMQX_PLUGIN_KAFKA_CONF"),
    case Env =:= "" orelse Env =:= false of
        true -> "etc/emqx_plugin_kafka.hocon";
        false -> Env
    end.

start_resource(Conf = #{connection := #{health_check_interval := HealthCheckInterval}}) ->
    ResId = emqx_plugin_kafka_util:resource_id(),
    ok = emqx_resource:create_metrics(ResId),
    Result = emqx_resource:create_local(
        ResId,
        ?PLUGIN_KAFKA_RESOURCE_GROUP,
        emqx_plugin_kafka_producer,
        Conf,
        #{health_check_interval => HealthCheckInterval}),
    start_resource_if_enabled(Result).

start_resource_if_enabled({ok, _Result = #{error := undefined, id := ResId}}) ->
    {ok, ResId};
start_resource_if_enabled({ok, #{error := Error, id := ResId}}) ->
    ?SLOG(error, #{
        msg => "start resource error",
        error => Error,
        resource_id => ResId
    }),
    emqx_resource:stop(ResId),
    emqx_resource:remove_local(ResId),
    error.

hooks(#{producer := Producer, hooks := Hooks}) ->
    ?SLOG(info, #{msg => "emqx_plugin_kafka_setup_hooks", hooks_count => length(Hooks)}),
    emqx_plugin_kafka_hook:hooks(Hooks, Producer, []).

unload() ->
    emqx_plugin_kafka_hook:unhook(),
    ResId = emqx_plugin_kafka_util:resource_id(),
    emqx_resource:remove_local(ResId).

validate_hooks(#{hooks := Hooks}) ->
    lists:foldl(
        fun
            (Hook, ok) -> validate_hook(Hook);
            (_, {error, _} = Error) -> Error
        end,
        ok,
        Hooks
    ).

validate_hook(#{endpoint := Endpoint, filter := Filter}) ->
    case is_message_endpoint(Endpoint) of
        true -> validate_message_filter(Filter);
        false -> ok
    end.

is_message_endpoint("message.publish") -> true;
is_message_endpoint("message.delivered") -> true;
is_message_endpoint("message.acked") -> true;
is_message_endpoint("message.dropped") -> true;
is_message_endpoint(_) -> false.

validate_message_filter(Filter) when is_binary(Filter), byte_size(Filter) > 0 ->
    case Filter of
        <<$#, _/binary>> ->
            {error, {invalid_message_filter, Filter}};
        <<$+, _/binary>> ->
            {error, {invalid_message_filter, Filter}};
        _ ->
            ok
    end;
validate_message_filter(Filter) ->
    {error, {invalid_message_filter, Filter}}.
