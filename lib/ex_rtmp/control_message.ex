defmodule ExRTMP.ControlMessage do
  @moduledoc """
  `ExRTMP.ControlMessage` RTMP control message

  Control messages are not AMF encoded. They start with a stream Id of 0x02 
    which implies a full (type 0) header and have a message type of 0x04, then
    followed by 6 bytes.
  """

  @control_type %{
    0x0 => :clear_stream,
    0x01 => :clear_buffer,
    0x02 => :stream_dry,
    0x03 => :client_buffer_time,
    0x04 => :reset_stream,
    0x06 => :client_pinged,
    0x07 => :client_ponged,
    0x08 => :udp_request,
    0x09 => :udp_response,
    0x0a => :bandwidth_limit,
    0x0b => :bandwidth,
    0x0c => :throttle_bandwidth,
    0x0d => :stream_created,
    0x0e => :stream_deleted,
    0x0f => :set_read_access,
    0x10 => :set_write_access,
    0x11 => :stream_meta_request,
    0x12 => :stream_meta_response,
    0x13 => :get_segment_boundary,
    0x14 => :set_segment_boundary,
    0x15 => :on_disconnect,
    0x16 => :set_critical_link,
    0x17 => :disconnect,
    0x18 => :hash_update,
    0x19 => :hash_timeout,
    0x1a => :hash_request,
    0x1b => :hash_response,
    0x1c => :check_bandwidth,
    0x1d => :set_audio_sample_acceses,
    0x1e => :set_video_sample_acceses,
    0x1f => :throttle_begin,
    0x20 => :throttle_end,
    0x21 => :drm_notify,
    0x22 => :rtmfp_sync,
    0x23 => :query_ihello,
    0x24 => :forward_ihello,
    0x25 => :redirect_ihello,
    0x26 => :notify_eof,
    0x27 => :proxy_continue,
    0x28 => :proxy_remove_upstream,
    0x29 => :rtmfp_set_keepalive,
    0x2e => :segment_not_found
  }

  @doc"""
  new/1 interpreted a control message
  """
  def new(<<0x06::size(16), timestamp::size(32)>>) do
    %{type: :ping_client, timestamp: timestamp}
  end

  def new(msg) do
     {:error, :invalid_format}
  end
end
