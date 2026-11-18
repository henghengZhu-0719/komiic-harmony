/**
 * 阅读页：竖向连续滚动，点中间呼出控制条，支持上一话 / 下一话。
 *
 * 方向：默认跟传感器转（尊重系统旋转锁定）；两指拧一下强制锁竖 / 锁横，
 * 控制条右上角那颗按钮也能换档。横屏时整页按屏幕高度贴合，一屏一页。
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { KomiicImage } from '../components/KomiicImage';
import { chapterRefererOf, imageUrlOf } from '../komiic/Config';
import { getSdk } from '../komiic/Sdk';
import { ChapterRef, KomiicImage as KomiicImageData, PageRef } from '../komiic/Types';
import {
  applyOrientation,
  nextOrientationMode,
  OrientationMode,
  orientationLabel,
  orientationModeKey,
  parseOrientationMode,
  releaseOrientation
} from '../utils/Orientation';

export interface ReaderParams {
  comicId: string;
  chapterId: string;
  chapterName: string;
}

/** Area 里的长度可能是数字也可能是带单位的字符串，统一成 vp 数字。 */
function toVp(value: Length): number {
  const parsed = Number.parseFloat(`${value}`);
  return Number.isNaN(parsed) ? 0 : parsed;
}

@Entry
@Component
struct Reader {
  @State private comicId: string = '';
  @State private chapterId: string = '';
  @State private chapterName: string = '';

  @State private chapters: ChapterRef[] = [];
  @State private pages: PageRef[] = [];
  @State private loading: boolean = true;
  @State private errorText: string = '';
  @State private showControls: boolean = false;
  @State private currentIndex: number = 0;

  @State private orientationMode: OrientationMode = OrientationMode.AUTO;
  /** 内容区实测尺寸（vp），横竖屏判断和整页贴合都靠它。 */
  @State private viewWidth: number = 0;
  @State private viewHeight: number = 0;

  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params = router.getParams() as ReaderParams;
    if (params !== undefined && params !== null) {
      this.comicId = params.comicId;
      this.chapterId = params.chapterId;
      this.chapterName = params.chapterName;
    }
    this.load();
    this.restoreOrientation();
  }

  aboutToDisappear(): void {
    // 整章大图占内存，离开就放开引用（磁盘缓存还在，回来不用重下）。
    const context = getContext(this) as common.Context;
    getSdk(context).then((sdk) => sdk.images.clearMemory());
    releaseOrientation(context);
  }

  /** 上次锁的方向记在 preferences 里，进来就恢复。 */
  private async restoreOrientation(): Promise<void> {
    const context = getContext(this) as common.Context;
    try {
      const sdk = await getSdk(context);
      this.orientationMode = parseOrientationMode(await sdk.store.getReaderOrientation());
    } catch (e) {
      this.orientationMode = OrientationMode.AUTO;
    }
    await applyOrientation(context, this.orientationMode);
  }

  private setOrientationMode(mode: OrientationMode): void {
    if (mode === this.orientationMode) {
      return;
    }
    this.orientationMode = mode;
    const context = getContext(this) as common.Context;
    applyOrientation(context, mode);
    getSdk(context).then((sdk) => sdk.store.setReaderOrientation(orientationModeKey(mode)));
    promptAction.showToast({ message: `屏幕方向：${orientationLabel(mode)}` });
  }

  /**
   * 两指拧动：往哪边拧就锁哪边，已经锁在那边再拧一次回到自动。
   * 拧的方向和锁定方向对不上手感的话，往另一边拧就是了。
   */
  private onTwist(angle: number): void {
    const target = angle < 0 ? OrientationMode.LANDSCAPE : OrientationMode.PORTRAIT;
    this.setOrientationMode(this.orientationMode === target ? OrientationMode.AUTO : target);
  }

  /** 转屏后内容区尺寸会变，这里顺手把当前页重新对齐到屏幕顶端。 */
  private onResize(area: Area): void {
    const width = toVp(area.width);
    const height = toVp(area.height);
    if (width <= 0 || height <= 0) {
      return;
    }
    const wasLandscape = this.isLandscape();
    this.viewWidth = width;
    this.viewHeight = height;
    // 只有 List 真的在屏幕上时 scroller 才可用，加载中 / 出错时别碰。
    const listAlive = !this.loading && this.errorText.length === 0 && this.pages.length > 0;
    if (listAlive && this.isLandscape() !== wasLandscape) {
      this.scroller.scrollToIndex(this.currentIndex);
    }
  }

  private isLandscape(): boolean {
    return this.viewHeight > 0 && this.viewWidth > this.viewHeight;
  }

  /** 竖屏还是老样子长图连读；横屏把整页压进一屏。 */
  private pageMaxHeight(): number {
    return this.isLandscape() ? this.viewHeight : 0;
  }

  private async load(): Promise<void> {
    if (this.comicId.length === 0 || this.chapterId.length === 0) {
      this.errorText = '参数缺失';
      this.loading = false;
      return;
    }
    this.loading = true;
    this.errorText = '';
    try {
      const sdk = await getSdk(getContext(this) as common.Context);

      if (this.chapters.length === 0) {
        this.chapters = await sdk.api.chapterRefs(this.comicId);
      }

      const images = await sdk.api.imagesByChapterId(this.chapterId);
      const referer = chapterRefererOf(this.comicId, this.chapterId);
      const pages: PageRef[] = [];
      images.forEach((item: KomiicImageData, index: number) => {
        const kid = (item.kid ?? '').trim();
        if (kid.length === 0) {
          return;
        }
        const page: PageRef = {
          id: (item.id ?? '').trim().length > 0 ? (item.id ?? '') : `${this.chapterId}-${index}`,
          url: imageUrlOf(kid),
          referer: referer,
          index: index + 1
        };
        pages.push(page);
      });

      if (pages.length === 0) {
        this.errorText = '这一话没有图片';
      }
      this.pages = pages;
      this.currentIndex = 0;
      this.scroller.scrollEdge(Edge.Top);
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message;
    } finally {
      this.loading = false;
    }
  }

  private indexOfCurrentChapter(): number {
    for (let i = 0; i < this.chapters.length; i++) {
      if (this.chapters[i].id === this.chapterId) {
        return i;
      }
    }
    return -1;
  }

  private jumpChapter(delta: number): void {
    const current = this.indexOfCurrentChapter();
    if (current < 0) {
      promptAction.showToast({ message: '找不到当前章节' });
      return;
    }
    const next = current + delta;
    if (next < 0 || next >= this.chapters.length) {
      promptAction.showToast({ message: delta > 0 ? '已经是最后一话' : '已经是第一话' });
      return;
    }
    const target = this.chapters[next];
    this.chapterId = target.id;
    this.chapterName = target.name;
    this.showControls = false;
    this.load();
  }

  @Builder
  controlBar() {
    Column() {
      // 顶部
      Row() {
        Text('返回')
          .fontSize(15)
          .fontColor(Color.White)
          .onClick(() => router.back())

        Text(this.chapterName)
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 12, right: 12 })

        Text(orientationLabel(this.orientationMode))
          .fontSize(13)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .borderRadius(14)
          .backgroundColor('rgba(255,255,255,0.18)')
          .onClick(() => this.setOrientationMode(nextOrientationMode(this.orientationMode)))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('rgba(0,0,0,0.75)')

      Blank()

      // 底部
      Row() {
        Button('上一话')
          .layoutWeight(1)
          .backgroundColor('rgba(255,255,255,0.15)')
          .fontColor(Color.White)
          .onClick(() => this.jumpChapter(-1))

        Text(`${this.currentIndex + 1} / ${this.pages.length}`)
          .fontSize(13)
          .fontColor(Color.White)
          .padding({ left: 16, right: 16 })

        Button('下一话')
          .layoutWeight(1)
          .backgroundColor('rgba(255,255,255,0.15)')
          .fontColor(Color.White)
          .onClick(() => this.jumpChapter(1))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 20 })
      .backgroundColor('rgba(0,0,0,0.75)')
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Stack() {
      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text('加载中…')
            .fontSize(13)
            .fontColor(Color.White)
            .margin({ top: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorText.length > 0) {
        Column() {
          Text(this.errorText)
            .fontSize(14)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
          Row() {
            Button('重试').onClick(() => this.load())
            Button('返回')
              .margin({ left: 12 })
              .backgroundColor('rgba(255,255,255,0.15)')
              .onClick(() => router.back())
          }
          .margin({ top: 14 })
        }
        .width('100%')
        .height('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.pages, (page: PageRef) => {
            ListItem() {
              KomiicImage({
                url: page.url,
                referer: page.referer,
                autoHeight: true,
                boxWidth: this.viewWidth,
                maxHeight: this.pageMaxHeight()
              })
                .width('100%')
            }
          }, (page: PageRef) => page.id)

          // 末尾的下一话入口，读完直接点。
          ListItem() {
            Column() {
              Text('本话结束')
                .fontSize(14)
                .fontColor(Color.White)
              Button('下一话')
                .margin({ top: 12 })
                .onClick(() => this.jumpChapter(1))
            }
            .width('100%')
            .padding({ top: 30, bottom: 50 })
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .cachedCount(2)
        .onScrollIndex((start: number) => this.currentIndex = start)
        .onClick(() => this.showControls = !this.showControls)
      }

      if (this.showControls && !this.loading) {
        this.controlBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((oldArea: Area, newArea: Area) => this.onResize(newArea))
    // 两指的手势，跟 List 的单指滚动不打架；priority 是为了不被列表先吃掉。
    .priorityGesture(
      RotationGesture({ fingers: 2, angle: 15 })
        .onActionEnd((event: GestureEvent) => this.onTwist(event.angle))
    )
  }
}
