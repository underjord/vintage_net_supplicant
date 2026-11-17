<!--
  SPDX-FileCopyrightText: None
  SPDX-License-Identifier: CC0-1.0
-->

# Changelog

## Unreleased

* Initial release. Extracted from `vintage_net_wifi` v0.12.12.
* Run `wpa_supplicant` with stdin connected to `/dev/null` so that it can't
  hang on a prompt, like the PKCS #11 engine asking for a missing PIN
