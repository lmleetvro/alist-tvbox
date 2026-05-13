declare module '@/utils/pluginDragSupport.mjs' {
  export const MOBILE_PLUGIN_DRAG_MAX_WIDTH: number

  export function isPluginDragEnabledForWidth(width: number): boolean
}
