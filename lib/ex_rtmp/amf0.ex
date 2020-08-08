defmodule ExRTMP.AMF0 do
  @moduledoc """
  AMF0 reader and writer

  Command messages have message type value of 20 for AMF0, and 17 for AMF3.
    Each command consists of a name, transaction ID and object

  https://www.adobe.com/content/dam/acom/en/devnet/pdf/amf0-file-format-specification.pdf
  https://en.wikipedia.org/wiki/Action_Message_Format

  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  | 16 bits | 16 bits       | header count*56 | 16 bits       | message count*64 |
  |         |               | + bits          |               | +bits            |
  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  |         |               |                 |               |                  |
  | Version | Header Count  | Header Type     | Message Count | Message Type     |
  |         |               |                 |               |                  |
  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  AMF packet
  16 bits                       - version. Default: 0 or 3
  16 bits                       - header count. Default: 0
  header count * 56 + bits      - header type structure
  16 bits                       - message count. Default 1
  message count * 64 + bits     - message type structure

  Header Type
  16 bits                       - header name length. Default 0
  header-name-length * 8 bits   - header name string
  8 bits                        - must understand
  32 bits                       - header length
  header-length * 8 bits        - amf0 or amf3

  Message type structure
  16 bits                       - target uri length
  target-uri-length * 8 bits    - target-uri-string
  16 bits                       - response uri length
  response-uri-length * 8 bits  - response uri string
  32 bits                       - message length
  message-length * 8 bits       - amf0 or amf3
  """
  @type data_type ::
          :number
          | :boolean
          | :string
          | :object
          | :null
          | :ecma_array
          | :object_end
          | :strict_array
          | :date
          | :long_string
          | :xml
          | :typed_object
          | :switch

  @data_types %{
    0x0 => :number,
    0x1 => :boolean,
    0x2 => :string,
    0x3 => :object,
    0x5 => :null,
    0x8 => :ecma_array,
    0x9 => :object_end,
    0xA => :strict_array,
    0xB => :date,
    0xC => :long_string,
    0xF => :xml,
    0x10 => :typed_object,
    0x11 => :switch
  }

  @doc """
  new/2 create a new AMF0 message
  """
  def new(body) when is_integer(body) do
    type_ = get_data_type_code(:number)
    <<type_, body::float-64>>
  end

  def new(body, data_type \\ :string) do
    type_ = get_data_type_code(data_type)

    IO.inspect("Type: #{type_}")

    cond do
      is_binary(body) ->
        l = byte_size(body)
        <<type_, 0x0, l>> <> body

      is_integer(body) ->
        <<type_, 0x0, 2>>

      # TODO: Remove this
      true ->
        throw("Not implemented")
    end
  end

  defp get_data_type_code(data_type) do
    @data_types |> Enum.filter(fn {k, v} -> v == data_type end) |> List.first() |> elem(0)
  end

  def c0, do: <<0x03>>

  def c1 do
    1528 |> :crypto.strong_rand_bytes() |> c1()
  end

  def c1(rand) do
    # time 4 bytes +  + 1528 = 1536 octets
    time = <<0, 0, 0, 0>>
    zeros = <<0::4*4>>
    time <> zeros <> rand
  end

  def c2, do: nil

  def s0, do: <<0x03>>

  def s1 do
    1528 |> :crypto.strong_rand_bytes() |> s1()
  end

  def s1(rand) do
    time = <<0, 0, 0, 0>>
    zeros = <<0::4*4>>
    time <> zeros <> rand
  end

  def s2, do: nil

  # TOOD: Remove and rename

  defstruct [:amf, :body, :command, :length, :marker, :tail, :version]

  @type t :: %__MODULE__{
          amf: nil,
          body: nil,
          command: nil,
          length: nil,
          marker: nil,
          tail: nil,
          version: nil
        }

  def deserialize(<<0x0, _rest::bits>> = message), do: deserialize(message, {:amf_version, :amf0})

  def deserialize(<<0x3, _rest::bits>> = message), do: deserialize(message, {:amf_version, :amf3})

  def deserialize(_invalid_message), do: {:error, :invalid_message_format}

  def deserialize(
        <<version::unsigned-16-little, header_count::unsigned-16-little, _rest::bits>> = message,
        {:amf_version, amf_version}
      ) do
    case read_message(message) do
      {:ok, message_map} ->
        {:ok,
         %__MODULE__{
           amf: amf_version,
           version: version,
           body: message_map
           # command: get_command_from(parsed_body),
           # marker: :object_marker
         }}

      error ->
        error
    end
  end

  def read_message(<<0x3, 0x0, body::bits>> = message) do
    read_message(body, %{})
  end

  def read_message(_invalid_message), do: {:error, :invalid_message_format}

  def read_message(<<0x0, rest::bits>>, message_map), do: read_message(rest, message_map)

  def read_message(<<0x9, _rest::bits>>, message_map), do: {:ok, message_map}

  def read_message(<<key_length::unsigned, body::bits>>, message_map) do
    case body do
      <<key::bytes-size(key_length), rest::bits>> ->
        read_message({:value, key}, rest, message_map)

      _ ->
        {:error, :invalid_message_format}
    end
  end

  def read_message({:value, key}, <<0x0, value::float-64, rest::bits>>, message_map) do
    read_message(rest, Enum.into(%{key => value}, message_map))
  end

  def read_message({:value, key}, <<0x2, 0x0, value_length::unsigned, body::bits>>, message_map) do
    case body do
      <<value::bytes-size(value_length), rest::bits>> ->
        read_message(rest, Enum.into(%{key => value}, message_map))

      _ ->
        {:error, :invalid_message_format}
    end
  end

  def read_message(_invalid_message, _empty, _message_map), do: {:error, :invalid_message_format}
end
