<!--
  SPDX-FileCopyrightText: 2024 Lars Wikman
  SPDX-License-Identifier: CC-BY-4.0
-->
# VintageNetSupplicant

Shared `wpa_supplicant` support for [VintageNet](https://github.com/nerves-networking/vintage_net)
technologies.

This is the `wpa_supplicant` daemon startup, control socket, message decoding
and EAP status tracking from
[`vintage_net_wifi`](https://github.com/nerves-networking/vintage_net_wifi),
pulled out so that `vintage_net_ethernet` can use it for wired IEEE 802.1X and
MACsec without depending on the WiFi library.

Nothing WiFi-specific lives here. Access points, scanning, mesh peers, signal
info and WPS stay in `vintage_net_wifi` under their existing names.

Extracted from `vintage_net_wifi` v0.12.12.

## Use

This is not a `VintageNet.Technology`. For authentication-only uses like wired
IEEE 802.1X, a technology writes the `wpa_supplicant` configuration file and
adds `VintageNetSupplicant.WPASupplicant` to its raw config's child specs:

```elixir
%VintageNet.Interface.RawConfig{
  files: [{wpa_supplicant_conf_path, contents}],
  child_specs: [
    {VintageNetSupplicant.WPASupplicant,
     wpa_supplicant: "wpa_supplicant",
     ifname: ifname,
     driver: "wired",
     wpa_supplicant_conf_path: wpa_supplicant_conf_path,
     control_path: control_interface_dir}
  ]
}
```

It publishes EAP progress to the interface's `eap_status` property.

Technologies that need more, like `vintage_net_wifi`, run their own process
using `VintageNetSupplicant.Daemon`, `VintageNetSupplicant.WPASupplicantLL`,
`VintageNetSupplicant.WPASupplicantDecoder` and `VintageNetSupplicant.EAP`.

## Installation

```elixir
def deps do
  [
    {:vintage_net_supplicant, github: "underjord/vintage_net_supplicant"}
  ]
end
```
