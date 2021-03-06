# ReinterpretCast

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `reinterpret_cast` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:reinterpret_cast, "~> 0.1.0", github: "cocoa-xu/reinterpret_cast"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/reinterpret_cast>.

## Description

Erlang does not allow `NAN` and `INFINITY` in their floating-point terms. There is no `:math.isnan/1` or `:math.isinf/1` for the users.

On the other hand, Erlang allows NIFs to send binary data (that represents a list of floating-point values). And sometimes, you cannot check for `NAN`s or `INFINITY`s in NIFs as they might be provided by a third-party and you don't have the source code.

Even if you have the source code, that means you'll have to maintain a fork of that NIF library and change all your libraries that depend on that third-party library to your own fork, the fork that maps `NAN`s and `INFINITY`s to some valid values.

Another case is that when you have to read a binary file that contains floating-point numbers in, of course, binary form.

We could write another NIF that checks and replaces the `NAN`s and `INFINITY`s to valid values, but in that case, you'll have to have a compiler available in your environment.

If only we could do that in pure Erlang/Elixir, oh, we probably can!

In C/C++, nothing is better than the good old school cast, 

```c
#include <math.h>
#include <inttypes.h>
#include <stdio.h>

int main() {
  float f32 = INFINITY;
  uint32_t f32_in_u32 = *(uint32_t*)f32;
  printf("INFINITY in uint32 representation: %d\n", f32_in_u32);
  // NAN in int32 representation: 2139095040
}
```

Note that the values here depends on the floating-point standard that your compiler uses. And `NAN`s/`INFINITY`s may have multiple values in the corresponding integer representation.

For example, a floating-point value is `NAN` as long as their exponent field is `1111 1111` (`0xFF`) and the fraction field is non-zero in [IEEE 754-1985](https://en.wikipedia.org/wiki/IEEE_754-1985#Representation_of_non-numbers). The most-significant-bit for `NAN` can be either `0` or `1`.

Now, whenever you have a `MatchError` in Elixir, you can refer to the IEEE standard and test the corresponding fields. For example, for a 32-bit float value, if the exponent field is `1111 1111` (`0xFF`) and the fraction field is non-zero, then it is `NAN` according to IEEE 754-1985.

In some sense, 32-bit and 64-bit float values can be decomposed using the following match

```elixir
# when f32_value_in_binary is little-endian
<< fraction_field::23, exponent_field::8, sign::1 >> = f32_value_in_binary

# when f32_value_in_binary is big-endian
<< sign::1, exponent_field::8, fraction_field::23 >> = f32_value_in_binary

# when f64_value_in_binary is little-endian
<< fraction_field::52, exponent_field::11, sign::1 >> = f64_value_in_binary

# when f64_value_in_binary is big-endian
<< sign::1, exponent_field::11, fraction_field::52 >> = f64_value_in_binary
```

Unfortunately, for float values in little-endian, the bits in memory are quite different. For example, `0xFFC0_0000` (`<<255, 192, 0, 0>>`) is a valid `NAN` if it is a 32-bit big-endian float value. The bitstring for `0xFFC0_0000` is

```
0b1_11111111_10000000000000000000000
```

And we can do the following match
```elixir
<< sign::1, exponent_field::8, fraction_field::23 >> = << 255, 192, 0, 0 >>
1       = sign
255     = exponent_field
4194304 = fraction_field
```

For the same `NAN` but in little-endian, we see `0x0000_C0FF` (`<<0, 0, 192, 255>>`), and the bitstring for that is

```
0b00000000_00000000_11000000_11111111
```

Therefore, when you try to match it in Elixir using the following statement, you will end up with wrong values

```elixir
<< fraction_field::23, exponent_field::8, sign::1 >> = << 0, 0, 192, 255 >>
1   = sign
127 = exponent_field
96  = fraction_field
```

Technically, we can swap the byte order and match the new binary using the big-endian statement if we know that we are dealing with little-endian float values.

Another possible approach is to use more fields in the match statement, and assemble them back to the correct `sign`, `exponent_field` and `fraction_field` later. But it is obviously more complicated and has more operations for handling one float number.

The first approach will swap 4 bytes (or 8 bytes) and will need bit masks in the backend when we match the new binary to the bitstring. It should be fast enough, but do we have any other options?

For most if not all real-life cases, programs will use fixed values for `NAN`s and `INFINITY`s, for examples,

```elixir
# 32-bit little-endian float
nan          = << 0, 0, 192, 255 >>
positive_inf = << 0, 0, 128, 127 >>
negative_inf = << 0, 0, 128, 255 >>
```

So for dealing with 32-bit little-endian floats, we just need to pass the binary data to a function that chunks it to correct size, 4 bytes for `f32` and 8 bytes for `f64`. That leads us to `ReinterpretCast.chunk_binary/2`

```elixir
# read the binary file
binary = File.read!("/path/to/a/binary/file")
# chunks it by every 4 bytes
ReinterpretCast.chunk_binary(binary, 4)
```

Then you can use `Enum.map/2` to map illegal 32-bit little-endian float values to some valid ones.

To make things easier, we also have `ReinterpretCast.cast/2` to convert the binary data to a list (or you could do that directly in the `Enum.map`, depending on the need of your workflow, e.g., say you want to save the sanitised binary to a file)

```elixir
nan          = << 0, 0, 192, 255 >>
positive_inf = << 0, 0, 128, 127 >>
negative_inf = << 0, 0, 128, 255 >>

"/path/to/a/binary/file"
# read the binary file
|> File.read!()
# chunk binary data by every 4 bytes
|> ReinterpretCast.chunk_binary(4)
# deal with 32-bit little-endian float
|> Enum.map(fn f32 -> 
     case f32 do
        ^nan ->
          << 0, 0, 0, 0 >>

        ^positive_inf ->
          << 0, 0, 0, 0 >>

        ^negative_inf ->
          << 0, 0, 0, 0 >>
          
        # legal value
        _ ->
          f32
     end
   end)
# merge them back to a single binary
|> IO.iodata_to_binary()
# save the sanitised binary to a file
|> tap(&File.write!("/ok.binary", &1))
# convert the binary to 32-bit little-endian float values
|> ReinterpretCast.cast({:f, 32, :little})
```

To deal with 32-bit big-endian float values, just need to change the value of `nan`, `positive_inf` and `negative_inf` to the corresponding ones,

```
# 32-bit big-endian float
nan          = << 255, 192, 0, 0 >>
positive_inf = << 127, 128, 0, 0 >>
negative_inf = << 255, 128, 0, 0 >>
```

Furthermore, we have `ReinterpretCast.cast/3`. This function can be quite handy when you have a list of numbers. This list may come from some sensor on your IoT devices, or was sent to you by another node, or you pulled it from somewhere on the Internet (e.g., the parameter file for a neural network model).

The list itself may be a list of `uint8_t`s, but it actually should be interpreted as a list of 32-bit little-endian float values. In this case, you could use `ReinterpretCast.cast/3`

```elixir
list_of_u8_but_should_be_interpreted_as_f32
|> ReinterpretCast.cast({:u, 8, :little}, {:f, 32, :little})
```
