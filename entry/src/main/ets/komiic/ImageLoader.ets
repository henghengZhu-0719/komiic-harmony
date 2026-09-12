/**
 * 带请求头的图片加载。
 *
 * Komiic 的图片必须带 Referer + UA，而 ArkUI 的 Image 组件不支持自定义请求头，
 * 所以只能自己下字节流 → 解码成 PixelMap → 交给 Image 显示。
 * 顺带做两级缓存，不然翻页会反复走网络。
 */

import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { KomiicClient } from './Client';

/** 内存里最多留多少张解码后的图。翻页读漫画时这个值别太小。 */
const MEMORY_CACHE_LIMIT: number = 24;
const DISK_CACHE_DIR_NAME: string = 'komiic_images';

/** djb2，够用就行，只是拿来当文件名。 */
function hashKey(input: string): string {
  let hash = 5381;
  for (let i = 0; i < input.length; i++) {
    hash = ((hash * 33) ^ input.charCodeAt(i)) >>> 0;
  }
  return hash.toString(16);
}

interface PendingTask {
  promise: Promise<image.PixelMap>;
}

export class ImageLoader {
  private client: KomiicClient;
  private cacheDir: string = '';
  private memoryCache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  /** 显式维护插入顺序，当 LRU 近似用，不依赖 Map 的迭代器。 */
  private memoryOrder: string[] = [];
  /** 同一张图并发请求时共享一个任务，避免重复下载。 */
  private inFlight: Map<string, PendingTask> = new Map<string, PendingTask>();

  constructor(client: KomiicClient, cacheRoot: string) {
    this.client = client;
    this.cacheDir = cacheRoot + '/' + DISK_CACHE_DIR_NAME;
    this.ensureDir();
  }

  private ensureDir(): void {
    try {
      if (!fileIo.accessSync(this.cacheDir)) {
        fileIo.mkdirSync(this.cacheDir);
      }
    } catch (e) {
      // 目录建不出来就退化成只用内存缓存。
    }
  }

  private pathOf(url: string): string {
    return this.cacheDir + '/' + hashKey(url);
  }

  /** 主入口：拿到可直接喂给 Image 组件的 PixelMap。 */
  async load(url: string, referer: string): Promise<image.PixelMap> {
    const cached = this.memoryCache.get(url);
    if (cached !== undefined) {
      return cached;
    }

    const pending = this.inFlight.get(url);
    if (pending !== undefined) {
      return await pending.promise;
    }

    const task: Promise<image.PixelMap> = this.loadUncached(url, referer);
    this.inFlight.set(url, { promise: task });
    try {
      const pixelMap = await task;
      this.putMemory(url, pixelMap);
      return pixelMap;
    } finally {
      this.inFlight.delete(url);
    }
  }

  private async loadUncached(url: string, referer: string): Promise<image.PixelMap> {
    let buffer: ArrayBuffer | null = this.readDisk(url);
    if (buffer === null) {
      buffer = await this.client.fetchImageBytes(url, referer);
      this.writeDisk(url, buffer);
    }
    return await this.decode(buffer);
  }

  private async decode(buffer: ArrayBuffer): Promise<image.PixelMap> {
    const source = image.createImageSource(buffer);
    try {
      // 不指定尺寸，按原图解码；漫画长图交给 Image 组件自己缩放。
      return await source.createPixelMap();
    } finally {
      source.release();
    }
  }

  private readDisk(url: string): ArrayBuffer | null {
    const path = this.pathOf(url);
    try {
      if (!fileIo.accessSync(path)) {
        return null;
      }
      const stat = fileIo.statSync(path);
      if (stat.size <= 0) {
        return null;
      }
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const buffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        return buffer;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      return null;
    }
  }

  private writeDisk(url: string, buffer: ArrayBuffer): void {
    const path = this.pathOf(url);
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      try {
        fileIo.writeSync(file.fd, buffer);
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      // 写缓存失败不影响本次显示。
    }
  }

  /**
   * 淘汰时只从表里摘掉，不调用 PixelMap.release()。
   *
   * 同一张图可能同时被别的页面挂载着（比如首页封面和详情页封面是同一个对象），
   * release() 掉还在显示的 PixelMap 会白图甚至崩。这里丢掉引用就够了，
   * 没人再引用时 GC 会回收 native 内存。
   */
  private putMemory(url: string, pixelMap: image.PixelMap): void {
    if (!this.memoryCache.has(url)) {
      this.memoryOrder.push(url);
    }
    this.memoryCache.set(url, pixelMap);

    while (this.memoryOrder.length > MEMORY_CACHE_LIMIT) {
      const oldestKey = this.memoryOrder.shift();
      if (oldestKey === undefined) {
        break;
      }
      this.memoryCache.delete(oldestKey);
    }
  }

  /** 退出阅读页时调用，放开对整章大图的引用。同样不 release，理由见 putMemory。 */
  clearMemory(): void {
    this.memoryCache.clear();
    this.memoryOrder = [];
  }

  /** 设置页的「清除缓存」。 */
  clearDisk(): void {
    try {
      const names = fileIo.listFileSync(this.cacheDir);
      names.forEach((name: string) => {
        try {
          fileIo.unlinkSync(this.cacheDir + '/' + name);
        } catch (e) {
        }
      });
    } catch (e) {
    }
  }

  /** 缓存占用字节数，用于设置页展示。 */
  diskUsage(): number {
    let total = 0;
    try {
      const names = fileIo.listFileSync(this.cacheDir);
      names.forEach((name: string) => {
        try {
          total += fileIo.statSync(this.cacheDir + '/' + name).size;
        } catch (e) {
        }
      });
    } catch (e) {
    }
    return total;
  }
}
