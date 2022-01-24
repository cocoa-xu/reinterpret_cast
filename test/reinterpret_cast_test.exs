defmodule ReinterpretCastTest do
  use ExUnit.Case
  doctest ReinterpretCast

  test "Use ReinterpretCast to handle NAN" do
    nan = <<0, 0, 192, 255>>
    try do
      << _illegal_f32::float-size(32)-little >> = nan
    rescue
      e in MatchError ->
        %MatchError{term: <<0, 0, 192, 255>>} = e
        assert true =
          nan
          |> ReinterpretCast.cast({:i, 32, :little})
          |> Enum.map(fn f32_in_i32 ->
              case f32_in_i32 do
                # << 4290772992::integer()-size(32)-little >> = <<0, 0, 192, 255>>
                # i.e, NaN
                # maps NaN to some legal value based on your needs
                # e.g, 0
                # <<0::float()-size(32)-little>> = <<0, 0, 0, 0>>
                4290772992 -> 0
                # << 2139095040::integer()-size(32)-little >> = <<0, 0, 128, 127>>
                # i.e, INFINITY
                # maps INFINITY to some legal value based on your needs
                # e.g, 0
                # <<0::float()-size(32)-little>> = <<0, 0, 0, 0>>
                2139095040 -> 0
                # leave legal values as is
                _ -> f32_in_i32
              end
            end)
          |> ReinterpretCast.cast({:i, 32, :little}, {:f, 32, :little})
          |> Enum.all?(&(0.0 = &1))
    end
  end

  test "Use ReinterpretCast to handle INFINITY" do
    infinity = << 0, 0, 128, 127 >>
    try do
      << _illegal_f32::float-size(32)-little >> = infinity
    rescue
      e in MatchError ->
        %MatchError{term: <<0, 0, 128, 127>>} = e
        assert true =
          infinity
          |> ReinterpretCast.cast({:i, 32, :little})
          |> Enum.map(fn f32_in_i32 ->
              case f32_in_i32 do
                # << 4290772992::integer()-size(32)-little >> = <<0, 0, 192, 255>>
                # i.e, NaN
                # maps NaN to some legal value based on your needs
                # e.g, 0
                # <<0::float()-size(32)-little>> = <<0, 0, 0, 0>>
                4290772992 -> 0
                # << 2139095040::integer()-size(32)-little >> = <<0, 0, 128, 127>>
                # i.e, INFINITY
                # maps INFINITY to some legal value based on your needs
                # e.g, 0
                # <<0::float()-size(32)-little>> = <<0, 0, 0, 0>>
                2139095040 -> 0
                # leave legal values as is
                _ -> f32_in_i32
              end
            end)
          |> ReinterpretCast.cast({:i, 32, :little}, {:f, 32, :little})
          |> Enum.all?(&(0.0 = &1))
    end
  end
  
  test "Use ReinterpretCast to handle large data" do
    f32_binary = File.read!(Path.join([__DIR__, "f32-with-a-nan.bin"]))
    try do
      f32_binary
        |> :binary.bin_to_list()
        |> Enum.chunk_every(4)
        |> Enum.map(&IO.iodata_to_binary(&1))
        |> Enum.map(&(<<_f32::float()-size(32)-little>> = &1))
    rescue
      _e in MatchError ->
        start_time = :os.system_time(:millisecond)
        count = trunc(byte_size(f32_binary) / 4)
        assert count ==
          f32_binary
          |> ReinterpretCast.chunk_binary(4)
          |> Enum.map(fn f32 -> 
              case f32 do
                # NAN
                << 0, 0, 192, 255 >> ->
                  << 0, 0, 0, 0>>
          
                # Positive Inf
                << 0, 0, 128, 127 >> ->
                  << 0, 0, 0, 0>>
          
                # Negative Inf
                << 0, 0, 128, 255 >> ->
                  << 0, 0, 0, 0>>
          
                # legal value
                _ ->
                  f32
              end
            end)
          |> IO.iodata_to_binary()
          |> ReinterpretCast.cast({:f, 32, :little})
          |> Enum.count()
      end_time = :os.system_time(:millisecond)
      IO.puts("convert #{count} f32 numbers, elapsed time: #{end_time-start_time} ms")
    end
  end
end
