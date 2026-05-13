import test from 'node:test'
import assert from 'node:assert/strict'

import { isPluginDragEnabledForWidth } from './pluginDragSupport.mjs'

test('disables plugin drag sorting below 768px', () => {
  assert.equal(isPluginDragEnabledForWidth(767), false)
})

test('keeps plugin drag sorting enabled at 768px and above', () => {
  assert.equal(isPluginDragEnabledForWidth(768), true)
  assert.equal(isPluginDragEnabledForWidth(1024), true)
})
