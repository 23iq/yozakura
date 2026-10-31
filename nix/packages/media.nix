# Media packages: video, audio, players
{ pkgs }:

with pkgs; [
  gpu-screen-recorder

  ffmpeg
  x264
  playerctl

  # GStreamer (QtMultimedia video backend for wallpapers)
  gst_all_1.gstreamer
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-good
  gst_all_1.gst-plugins-bad
  gst_all_1.gst-libav

  # Audio: wpctl and pw-record/pw-play from PipeWire, pactl/paplay/
  # parecord (media idle inhibit, sounds, voice fallback), event sounds
  pipewire
  wireplumber
  pulseaudio
  libcanberra-gtk3
  sound-theme-freedesktop
  cava
]
