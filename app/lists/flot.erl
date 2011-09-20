fun(Head, {Req}) ->
  Stamp = fun(Fields) ->
    case length(Fields) of
      1 -> [Year] = Fields,
        {{Year, 1, 1}, {0, 0, 0}};
      2 -> [Year, Month] = Fields,
        {{Year, Month, 1}, {0, 0, 0}};
      3 -> [Year, Month, Day] = Fields,
        {{Year, Month, Day}, {0, 0, 0}};
      4 -> [Year, Month, Day, Hour] = Fields,
        {{Year, Month, Day}, {Hour, 0, 0}};
      5 -> [Year, Month, Day, Hour, Minute] = Fields,
        {{Year, Month, Day}, {Hour, Minute, 0}};
      6 -> [Year, Month, Day, Hour, Minute, Second] = Fields,
        {{Year, Month, Day}, {Hour, Minute, Second}};
      _ -> {{1970, 1, 1}, {0, 0, 0}}
    end
  end,

  Epoch = fun(Gregorian) ->
    UnixG = calendar:datetime_to_gregorian_seconds(Gregorian),
    UnixE = calendar:datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}}),
    UnixG - UnixE
  end,

  Fold = fun({Row}, Dict) ->
    {[{<<"key">>, Key}, {<<"value">>, Bytes}]} = {Row},
    [Hostname, DestIP | Timestamp] = Key, %% group_level >= 2
    Unix = Epoch(Stamp(Timestamp)),
    case dict:find(DestIP, Dict) of
      {ok, Data} ->
        {ok, dict:store(DestIP, Data ++ [[Unix, Bytes]], Dict)};
      _ ->
        {ok, dict:store(DestIP, [[Unix, Bytes]], Dict)}
    end
  end,

  Deep = fun(Elem, {Flag, Acc}) ->
    case Flag of
      false ->
	{true, Acc ++ <<"[",Elem,",">>};
      true ->
	{false, Acc ++ <<Elem,"]">>} 
    end
  end,

  {ok, Stats} = FoldRows(Fold, dict:new()),

  Send(<<"{[">>),

  dict:fold(
    fun(Key, Value, In) ->
      case In of
        <<",">> ->
          Send(In);
        _ -> ok
      end,
      Send(<<"{\"label\":\"", Key/binary, "\",\"data\":">>),
      {_, Bin} = lists:foldl(Deep, {false, <<"">>}, Value),
      Send(Bin),
      Send(<<"}">>),
      <<",">>
    end, nil, Stats),

  <<"]}">>
end.
