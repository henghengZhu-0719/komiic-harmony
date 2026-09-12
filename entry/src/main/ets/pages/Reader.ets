/**
 * 阅读页：竖向连续滚动，点中间呼出控制条，支持上一话 / 下一话。
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { KomiicImage } from '../components/KomiicImage';
import { chapterRefererOf, imageUrlOf } from '../komiic/Config';
import { getSdk } from '../komiic/Sdk';
import { ChapterRef, KomiicImage as KomiicImageData, PageRef } from '../komiic/Types';

export interface ReaderParams {
  comicId: string;
  chapterId: string;
  chapterName: string;
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

  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params = router.getParams() as ReaderParams;
    if (params !== undefined && params !== null) {
      this.comicId = params.comicId;
      this.chapterId = params.chapterId;
      this.chapterName = params.chapterName;
    }
    this.load();
  }

  aboutToDisappear(): void {
    // 整章大图占内存，离开就放开引用（磁盘缓存还在，回来不用重下）。
    const context = getContext(this) as common.Context;
    getSdk(context).then((sdk) => sdk.images.clearMemory());
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
        Blank()
        Text(this.chapterName)
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
                autoHeight: true
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
  }
}
