-module(app_smtp_ffi).

-export([encode_message/7, send/8]).

%% Builds multipart/related(multipart/alternative(text, html), image/png...)
%% so receipt QR codes render inline via cid: references without remote loads.
encode_message(FromHeader, ToName, ToAddress, Subject, Text, Html, Images) ->
    Alternative =
        {<<"multipart">>, <<"alternative">>, [], #{},
         [text_part(<<"plain">>, Text), text_part(<<"html">>, Html)]},
    Body =
        case Images of
            [] -> Alternative;
            _ -> {<<"multipart">>, <<"related">>, [],
                  #{content_type_params => [{<<"type">>, <<"multipart/alternative">>}]},
                  [Alternative | [image_part(Image) || Image <- Images]]}
        end,
    {Type, Subtype, [], Params, Parts} = Body,
    Headers = [
        {<<"From">>, FromHeader},
        {<<"To">>, recipient_header(ToName, ToAddress)},
        {<<"Subject">>, Subject},
        {<<"Date">>, list_to_binary(smtp_util:rfc5322_timestamp())},
        {<<"Message-ID">>, list_to_binary(smtp_util:generate_message_id())},
        {<<"MIME-Version">>, <<"1.0">>}
    ],
    mimemail:encode({Type, Subtype, Headers, Params, Parts}).

send(FromAddress, ToAddress, Message, Host, Port, Username, Password, UseStartTls) ->
    Options = [
        {relay, Host},
        {port, Port},
        {username, Username},
        {password, Password},
        {auth, always},
        {tls, case UseStartTls of true -> always; false -> if_available end},
        {tls_options, tls_options(Host)},
        {retries, 0}
    ],
    try gen_smtp_client:send_blocking({FromAddress, [ToAddress], Message}, Options) of
        Receipt when is_binary(Receipt) -> {ok, nil};
        {error, Type, Detail} -> {error, describe({Type, Detail})};
        {error, Reason} -> {error, describe(Reason)}
    catch
        Class:Reason -> {error, describe({Class, Reason})}
    end.

text_part(Subtype, Content) ->
    {<<"text">>, Subtype, [],
     #{content_type_params => [{<<"charset">>, <<"utf-8">>}],
       transfer_encoding => <<"quoted-printable">>,
       disposition => <<"inline">>},
     Content}.

image_part({inline_image, ContentId, Filename, Png}) ->
    {<<"image">>, <<"png">>,
     [{<<"Content-ID">>, <<"<", ContentId/binary, ">">>}],
     #{content_type_params => [{<<"name">>, Filename}],
       transfer_encoding => <<"base64">>,
       disposition => <<"inline">>,
       disposition_params => [{<<"filename">>, Filename}]},
     Png}.

recipient_header(<<>>, Address) -> Address;
recipient_header(Name, Address) ->
    Sanitised = binary:replace(Name, [<<"\"">>, <<"\r">>, <<"\n">>], <<>>, [global]),
    <<"\"", Sanitised/binary, "\" <", Address/binary, ">">>.

tls_options(Host) ->
    HostName = binary_to_list(Host),
    [
        {verify, verify_peer},
        {cacerts, public_key:cacerts_get()},
        {server_name_indication, HostName},
        {customize_hostname_check, [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]},
        {versions, ['tlsv1.2', 'tlsv1.3']}
    ].

describe(Term) ->
    unicode:characters_to_binary(io_lib:format("~0p", [Term])).
