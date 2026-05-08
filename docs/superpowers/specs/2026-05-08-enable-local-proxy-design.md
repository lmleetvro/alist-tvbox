# Enable Local Proxy Design

**Date:** 2026-05-08

**Goal:** Add an advanced configuration toggle named `enable_local_proxy`, default it to enabled, and include the resolved value in `SubscriptionService#buildSite` so spiders can consume it through `ext`.

## Scope

This change applies to:
- The advanced settings UI in `web-ui/src/views/ConfigView.vue`
- Setting persistence and retrieval through the existing `/api/settings` flow
- Site `ext` generation in `src/main/java/cn/har01d/alist_tvbox/service/SubscriptionService.java`
- Targeted subscription service tests

Out of scope:
- Changing spider-side consumption logic
- Refactoring unrelated setting handling
- Changing the structure of non-built-in site definitions

## Current Behavior

The advanced settings dialog exposes several boolean toggles that persist through `/api/settings`.

`SubscriptionService#buildSite` currently builds a Base64-encoded JSON `ext` payload containing:
- `api`
- `token`
- `uid`

There is no UI setting or `ext` field for local proxy enablement.

## Requirements

### Functional

- Add a new advanced setting named `enable_local_proxy`.
- The setting must default to enabled when it is absent from storage.
- The advanced settings UI must show the switch as enabled when the setting is absent.
- Updating the switch must persist through the existing `/api/settings` endpoint.
- `SubscriptionService#buildSite` must include `enable_local_proxy` in the encoded `ext` payload for built-in spiders.

### Compatibility

- Existing installations without an `enable_local_proxy` row must continue to behave as enabled.
- Existing `ext` fields for built-in sites must remain backward compatible except for the new additional key.

## Design

### Frontend

Follow the existing default-enabled boolean pattern already used by settings such as `mix_site_source` and `ali_lazy_load`.

Implementation details:
- Add `enableLocalProxy` as a local `ref`
- Add `updateEnableLocalProxy()` that posts `{name: 'enable_local_proxy', value: enableLocalProxy.value}`
- Add a new switch in the advanced settings dialog with label `开启本地代理`
- During initial settings load, resolve the UI state with `data.enable_local_proxy !== 'false'`

This keeps the absent-setting case aligned with the required default of enabled.

### Backend

`SubscriptionService#buildSite` will resolve the setting from `SettingRepository` using:
- stored `false` => disabled
- stored `true` or missing => enabled

The `ext` JSON map will be expanded from:
- `api`
- `token`
- `uid`

to:
- `api`
- `token`
- `uid`
- `enable_local_proxy`

No other site generation logic changes.

### Testing

Add focused tests around `SubscriptionService#buildSite`/site generation to verify:
- Missing setting produces `enable_local_proxy: true`
- Explicit `false` produces `enable_local_proxy: false`

The tests should decode the generated Base64 `ext` payload and assert on the JSON values rather than string fragments.

## Error Handling

- No new runtime error handling is required.
- Missing settings are treated as an expected case and default to enabled.

## Acceptance Criteria

- The advanced settings dialog shows an `开启本地代理` switch.
- New installs and old installs without saved state show the switch as enabled.
- Toggling the switch persists through `/api/settings`.
- Built-in site `ext` payloads include `enable_local_proxy`.
- Targeted tests cover both the default-enabled and explicit-disabled cases.
