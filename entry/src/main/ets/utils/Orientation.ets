/**
 * 阅读页的屏幕方向。三档：自动（跟随传感器）/ 强制竖屏 / 强制横屏。
 *
 * 只有这个文件碰 window，页面用 applyOrientation / releaseOrientation。
 * 运行时设的方向优先级高于 module.json5 里的 orientation，所以不用改工程配置。
 */

import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export enum OrientationMode {
  AUTO,
  PORTRAIT,
  LANDSCAPE
}

const KEY_AUTO: string = 'auto';
const KEY_PORTRAIT: string = 'portrait';
const KEY_LANDSCAPE: string = 'landscape';

/** 存进 preferences 用的字符串。 */
export function orientationModeKey(mode: OrientationMode): string {
  if (mode === OrientationMode.PORTRAIT) {
    return KEY_PORTRAIT;
  }
  if (mode === OrientationMode.LANDSCAPE) {
    return KEY_LANDSCAPE;
  }
  return KEY_AUTO;
}

export function parseOrientationMode(key: string): OrientationMode {
  const normalized = key.trim().toLowerCase();
  if (normalized === KEY_PORTRAIT) {
    return OrientationMode.PORTRAIT;
  }
  if (normalized === KEY_LANDSCAPE) {
    return OrientationMode.LANDSCAPE;
  }
  return OrientationMode.AUTO;
}

export function orientationLabel(mode: OrientationMode): string {
  if (mode === OrientationMode.PORTRAIT) {
    return '竖屏';
  }
  if (mode === OrientationMode.LANDSCAPE) {
    return '横屏';
  }
  return '自动';
}

/** 控制条上按一下换一档：自动 → 竖屏 → 横屏 → 自动。 */
export function nextOrientationMode(mode: OrientationMode): OrientationMode {
  if (mode === OrientationMode.AUTO) {
    return OrientationMode.PORTRAIT;
  }
  if (mode === OrientationMode.PORTRAIT) {
    return OrientationMode.LANDSCAPE;
  }
  return OrientationMode.AUTO;
}

function toWindowOrientation(mode: OrientationMode): window.Orientation {
  if (mode === OrientationMode.PORTRAIT) {
    return window.Orientation.PORTRAIT;
  }
  if (mode === OrientationMode.LANDSCAPE) {
    return window.Orientation.LANDSCAPE;
  }
  // RESTRICTED：跟传感器转，但尊重系统的「旋转锁定」开关。
  return window.Orientation.AUTO_ROTATION_RESTRICTED;
}

/** 方向设置失败不该把页面搞崩，吞掉异常返回 false。 */
async function setOrientation(context: common.Context, orientation: window.Orientation): Promise<boolean> {
  try {
    const win = await window.getLastWindow(context);
    await win.setPreferredOrientation(orientation);
    return true;
  } catch (e) {
    return false;
  }
}

export async function applyOrientation(context: common.Context, mode: OrientationMode): Promise<boolean> {
  return await setOrientation(context, toWindowOrientation(mode));
}

/** 离开阅读页时还回去，别让别的页面跟着锁在横屏。 */
export async function releaseOrientation(context: common.Context): Promise<boolean> {
  return await setOrientation(context, window.Orientation.UNSPECIFIED);
}
