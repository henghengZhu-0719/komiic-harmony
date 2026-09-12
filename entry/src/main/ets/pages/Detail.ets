/**
 * 详情页：封面 + 元信息 + 章节列表 + 收藏。
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { KomiicImage } from '../components/KomiicImage';
import { authorLine, categoryNames, formatCount, formatDateTime, statusText } from '../komiic/Format';
import { getSdk } from '../komiic/Sdk';
import { ChapterRef, KomiicComic } from '../komiic/Types';
import { ReaderParams } from './Reader';

export interface DetailParams {
  comicId: string;
  title: string;
  coverUrl: string;
}

@Entry
@Component
struct Detail {
  @State private comicId: string = '';
  @State private title: string = '';
  @State private coverUrl: string = '';

  @State private comic: KomiicComic | null = null;
  @State private chapters: ChapterRef[] = [];
  @State private commentCount: number = 0;
  @State private favorited: boolean = false;
  @State private canFavorite: boolean = false;

  @State private loading: boolean = true;
  @State private errorText: string = '';
  @State private favoriteBusy: boolean = false;
  /** 章节倒序展示，通常是想看最新一话。 */
  @State private descending: boolean = true;

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams;
    if (params !== undefined && params !== null) {
      this.comicId = params.comicId;
      this.title = params.title;
      this.coverUrl = params.coverUrl;
    }
    this.load();
  }

  private async load(): Promise<void> {
    if (this.comicId.length === 0) {
      this.errorText = 'comicId 为空';
      this.loading = false;
      return;
    }
    this.loading = true;
    this.errorText = '';
    try {
      const sdk = await getSdk(getContext(this) as common.Context);

      // 详情和章节是必须的，并发拉。
      const comicTask = sdk.api.comicById(this.comicId);
      const chapterTask = sdk.api.chapterRefs(this.comicId);
      const comic = await comicTask;
      const chapters = await chapterTask;

      this.comic = comic;
      this.title = (comic.title ?? '').trim();
      this.coverUrl = (comic.imageUrl ?? '').trim();
      this.chapters = chapters;

      // 这两个失败不影响主内容。
      try {
        this.commentCount = await sdk.api.commentCount(this.comicId);
      } catch (e) {
      }
      try {
        const folderIds = await sdk.api.comicInAccountFolders(this.comicId);
        this.favorited = folderIds.length > 0;
        this.canFavorite = true;
      } catch (e) {
        // 未登录，隐藏收藏按钮。
        this.canFavorite = false;
      }
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message;
    } finally {
      this.loading = false;
    }
  }

  private async toggleFavorite(): Promise<void> {
    if (this.favoriteBusy) {
      return;
    }
    this.favoriteBusy = true;
    try {
      const sdk = await getSdk(getContext(this) as common.Context);
      const next = await sdk.api.toggleFavorite(this.comicId, this.favorited);
      this.favorited = next;
      promptAction.showToast({ message: next ? '已收藏' : '已取消收藏' });
    } catch (e) {
      const err = e as Error;
      promptAction.showToast({ message: err.message });
    } finally {
      this.favoriteBusy = false;
    }
  }

  private openChapter(chapter: ChapterRef): void {
    const params: ReaderParams = {
      comicId: this.comicId,
      chapterId: chapter.id,
      chapterName: chapter.name
    };
    router.pushUrl({ url: 'pages/Reader', params: params });
  }

  private displayChapters(): ChapterRef[] {
    if (!this.descending) {
      return this.chapters;
    }
    return this.chapters.slice().reverse();
  }

  @Builder
  header() {
    Row() {
      KomiicImage({ url: this.coverUrl, referer: '', imageFit: ImageFit.Cover })
        .width(110)
        .aspectRatio(0.72)
        .clip(true)
        .borderRadius(8)

      Column() {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.comic !== null) {
          Text('作者：' + (authorLine(this.comic).length > 0 ? authorLine(this.comic) : '未知'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .width('100%')
            .margin({ top: 6 })

          Text('状态：' + (statusText(this.comic).length > 0 ? statusText(this.comic) : '未知'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .margin({ top: 3 })

          Text('更新：' + formatDateTime(this.comic.dateUpdated))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .margin({ top: 3 })

          Text(`观看 ${formatCount(this.comic.views)} · 收藏 ${formatCount(this.comic.favoriteCount)} · 评论 ${this.commentCount}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 14, right: 14, top: 12 })
  }

  @Builder
  tagRow() {
    if (this.comic !== null && categoryNames(this.comic).length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(categoryNames(this.comic), (tag: string) => {
          Text(tag)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .margin({ right: 6, top: 6 })
        }, (tag: string) => tag)
      }
      .width('100%')
      .padding({ left: 14, right: 14 })
    }
  }

  @Builder
  actionRow() {
    Row() {
      Button(this.chapters.length > 0 ? '开始阅读' : '暂无章节')
        .layoutWeight(1)
        .enabled(this.chapters.length > 0)
        .onClick(() => {
          if (this.chapters.length > 0) {
            this.openChapter(this.chapters[0]);
          }
        })

      if (this.canFavorite) {
        Button(this.favorited ? '已收藏' : '收藏')
          .backgroundColor(this.favorited
            ? $r('sys.color.comp_background_tertiary') : $r('sys.color.comp_background_emphasize'))
          .fontColor(this.favorited ? $r('sys.color.font_primary') : Color.White)
          .margin({ left: 10 })
          .enabled(!this.favoriteBusy)
          .onClick(() => this.toggleFavorite())
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14 })
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('返回')
          .fontSize(15)
          .fontColor($r('sys.color.font_emphasize'))
          .onClick(() => router.back())
        Blank()
        Text(this.descending ? '倒序' : '正序')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .onClick(() => this.descending = !this.descending)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 6 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorText.length > 0) {
        Column() {
          Text(this.errorText)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center)
          Button('重试').margin({ top: 12 }).onClick(() => this.load())
        }
        .layoutWeight(1)
        .width('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.header()
            this.tagRow()
            this.actionRow()

            Text(`章节（${this.chapters.length}）`)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ left: 14, right: 14, top: 18, bottom: 8 })

            Grid() {
              ForEach(this.displayChapters(), (chapter: ChapterRef) => {
                GridItem() {
                  Text(chapter.name)
                    .fontSize(13)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .padding({ top: 10, bottom: 10 })
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    .borderRadius(6)
                    .onClick(() => this.openChapter(chapter))
                }
              }, (chapter: ChapterRef) => chapter.id)
            }
            .columnsTemplate('1fr 1fr 1fr')
            .columnsGap(8)
            .rowsGap(8)
            .width('100%')
            .padding({ left: 14, right: 14, bottom: 24 })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
