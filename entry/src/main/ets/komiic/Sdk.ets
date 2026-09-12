/**
 * 单例门面。页面只跟这个打交道，不直接 new Client/Api。
 *
 * 用法：
 *   const sdk = await getSdk(getContext(this) as common.Context);
 *   const list = await sdk.api.recentUpdate(1);
 */

import { common } from '@kit.AbilityKit';
import { KomiicApi } from './Api';
import { KomiicClient } from './Client';
import { ImageLoader } from './ImageLoader';
import { KomiicStore } from './Store';

export class KomiicSdk {
  store: KomiicStore;
  client: KomiicClient;
  api: KomiicApi;
  images: ImageLoader;

  constructor(store: KomiicStore, client: KomiicClient, api: KomiicApi, images: ImageLoader) {
    this.store = store;
    this.client = client;
    this.api = api;
    this.images = images;
  }
}

let instance: KomiicSdk | null = null;
let initTask: Promise<KomiicSdk> | null = null;

async function buildSdk(context: common.Context): Promise<KomiicSdk> {
  const store = new KomiicStore();
  await store.init(context);

  const client = new KomiicClient(store);
  const api = new KomiicApi(client);
  const images = new ImageLoader(client, context.cacheDir);

  // 冷启动静默登录；失败不阻塞，公开接口照样能用。
  await client.warmUp();

  return new KomiicSdk(store, client, api, images);
}

/** 幂等初始化，并发调用共享同一个任务。 */
export async function getSdk(context: common.Context): Promise<KomiicSdk> {
  if (instance !== null) {
    return instance;
  }
  const pending = initTask;
  if (pending !== null) {
    return await pending;
  }
  const task = buildSdk(context);
  initTask = task;
  try {
    const sdk = await task;
    instance = sdk;
    return sdk;
  } finally {
    initTask = null;
  }
}

/** 已经初始化过就同步拿，没有就返回 null（UI 里做兜底判断用）。 */
export function peekSdk(): KomiicSdk | null {
  return instance;
}
