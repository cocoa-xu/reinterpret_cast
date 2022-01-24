defmodule ReinterpretCast do
  @moduledoc """
  reinterpret_cast but in elixir
  """
  
  @typedoc """
  endianness for numbers
  """
  @type endianness_type() :: :little | :big
  
  @typedoc """
  allowed types for numbers
  """
  @type number_type() ::
    {:i, 8, endianness_type()}
    | {:i, 16, endianness_type()}
    | {:i, 32, endianness_type()}
    | {:i, 64, endianness_type()}
    | {:f, 32, endianness_type()}
    | {:f, 64, endianness_type()}
  
  @doc """
  This function casts a list of numbers to its binary form
  
  if target_type is `:binary`, 
  then this function casts the given list of numbers to its binary form
  """
  @spec cast(list(), number_type(), :binary) :: binary()
  def cast(list, source_type, :binary)
  when is_list(list) and is_tuple(source_type) do
    case source_type do
      {:i, bits, :little} ->
        list
        |> Enum.into(<<>>, fn data ->
          << data::integer()-size(bits)-little >>
        end)
      {:i, bits, :big} ->
        list
        |> Enum.into(<<>>, fn data ->
          << data::integer()-size(bits)-big >>
        end)
      {:f, bits, :little} ->
        list
        |> Enum.into(<<>>, fn data ->
          << data::float()-size(bits)-little >>
        end)
      {:f, bits, :big} ->
        list
        |> Enum.into(<<>>, fn data ->
          << data::float()-size(bits)-big >>
        end)
    end
  end

  @spec cast(list(), number_type(), number_type()) :: list()
  def cast(list, source_type, target_type)
  when is_list(list) and is_tuple(source_type) and is_tuple(target_type)
  do
    list
    |> cast(source_type, :binary)
    |> cast(target_type)
  end

  @doc """
  This function casts binary data to target type
  """
  @spec cast(binary(), number_type()) :: list()
  def cast(binary, _target_type={type, bits, endianness})
  when is_binary(binary) and (type == :i or type == :f) and (endianness == :little or endianness == :big) do
    with 0 <- rem(bits, 8),
          chunk_size <- div(bits, 8),
          0 <- rem(byte_size(binary), div(bits, 8)) do
      binary
      |> chunk_binary(chunk_size)
      |> _cast({type, bits, endianness})
    end
  end
  
  @doc """
  This function chunks binary data by every requested `chunk_size`
  
  To make it more general, this function allows the length of the last chunk
  to be less than the request `chunk_size`.
  
  For example, if you have a 7-byte binary data, and you'd like to chunk it by every
  4 bytes, then this function will return two chunks with the first gives you the 
  byte 0 to 3, and the second one gives byte 4 to 6.
  """
  def chunk_binary(binary, chunk_size) when is_binary(binary) do
    total_bytes = byte_size(binary)
    full_chunks = div(total_bytes, chunk_size)
    chunks =
      if full_chunks > 0 do
        for i <- 0..(full_chunks-1), reduce: [] do
          acc -> [:binary.part(binary, chunk_size * i, chunk_size) | acc]
        end
      else
        []
      end
    remaining = rem(total_bytes, chunk_size)
    chunks =
      if remaining > 0 do
        [:binary.part(binary, chunk_size * full_chunks, remaining) | chunks]
      else
        chunks
      end
    Enum.reverse(chunks)
  end
  
  defp _cast(binary_chunks, {:i, bits, :little}) do
    binary_chunks
    |> Enum.into([], fn chunk ->
      << to::integer()-size(bits)-little >> = chunk
      to
    end)
  end
  
  defp _cast(binary_chunks, {:i, bits, :big}) do
    binary_chunks
    |> Enum.into([], fn chunk ->
      << to::integer()-size(bits)-big >> = chunk
      to
    end)
  end
  
  defp _cast(binary_chunks, {:f, bits, :little}) do
    binary_chunks
    |> Enum.into([], fn chunk ->
      << to::float()-size(bits)-little >> = chunk
      to
    end)
  end
  
  defp _cast(binary_chunks, {:f, bits, :big}) do
    binary_chunks
    |> Enum.into([], fn chunk ->
      << to::float()-size(bits)-big >> = chunk
      to
    end)
  end
end
