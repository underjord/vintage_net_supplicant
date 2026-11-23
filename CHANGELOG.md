<!--
  SPDX-FileCopyrightText: None
  SPDX-License-Identifier: CC0-1.0
-->

# Changelog

## Unreleased

* Initial release. Extracted from `vintage_net_wifi` v0.12.12.
* Run `wpa_supplicant` with stdin connected to `/dev/null` so that it can't
  hang on a prompt, like the PKCS #11 engine asking for a missing PIN
* Report an EAP status of `:failure` when `wpa_supplicant` asks for a credential
  with a `CTRL-REQ-*` request, like for a wrong PIN. Nothing answers these
  requests, so the status used to stay at `:started`.
