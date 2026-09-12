/**
 * 首页：最近更新 / 排行榜 / 分类 三个 tab + 搜索。
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { KomiicImage } from '../components/KomiicImage';
import { CATEGORY_OPTIONS, RANKING_OPTIONS, LabeledOption } from '../komiic/Config';
import { authorLine, relativeUpdateText } from '../komiic/Format';
import { getSdk } from '../komiic/Sdk';
import { KomiicComic } from '../komiic/Types';
import { DetailParams } from './Detail';

enum FeedMode {
  Recent = 0,
  Ranking = 1,
  Category = 2,
  Search = 3
}

@Entry
@Component
struct Index {
  @State private mode: FeedMode = FeedMode.Recent;
  @State private comics: KomiicComic[] = [];
  @State private loading: boolean = false;
  @State private loadingMore: boolean = false;
  @State private reachedEnd: boolean = false;
  @State private errorText: string = '';
  @State private page: number = 1;

  @State private keyword: string = '';
  @State private rankingOrder: string = RANKING_OPTIONS[0].value;
  @State private categoryId: string = '0';

  aboutToAppear(): void {
    this.reload();
  }

  // ---------- 取数 ----------

  private async fetchPage(page: number): Promise<KomiicComic[]> {
    const sdk = await getSdk(getContext(this) as common.Context);
    if (this.mode === FeedMode.Recent) {
      return await sdk.api.recentUpdate(page);
    }
    if (this.mode === FeedMode.Ranking) {
      return await sdk.api.hotComics(page, this.rankingOrder);
    }
    if (this.mode === FeedMode.Category) {
      return await sdk.api.comicByCategories(page, this.categoryId, 'DATE_UPDATED', '');
    }
    // 搜索没有分页，第二页开始直接返回空。
    if (page > 1) {
      return [];
    }
    const result = await sdk.api.search(this.keyword.trim());
    return result.comics ?? [];
  }

  private async reload(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.errorText = '';
    this.page = 1;
    this.reachedEnd = false;
    try {
      const list = await this.fetchPage(1);
      this.comics = list;
      this.reachedEnd = list.length === 0;
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message;
      this.comics = [];
    } finally {
      this.loading = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || this.reachedEnd) {
      return;
    }
    this.loadingMore = true;
    const next = this.page + 1;
    try {
      const list = await this.fetchPage(next);
      if (list.length === 0) {
        this.reachedEnd = true;
      } else {
        this.comics = this.comics.concat(list);
        this.page = next;
      }
    } catch (e) {
      const err = e as Error;
      promptAction.showToast({ message: err.message });
    } finally {
      this.loadingMore = false;
    }
  }

  private switchMode(mode: FeedMode): void {
    if (this.mode === mode) {
      return;
    }
    this.mode = mode;
    this.reload();
  }

  private openDetail(comic: KomiicComic): void {
    const comicId = (comic.id ?? '').trim();
    if (comicId.length === 0) {
      return;
    }
    const params: DetailParams = {
      comicId: comicId,
      title: (comic.title ?? '').trim(),
      coverUrl: (comic.imageUrl ?? '').trim()
    };
    router.pushUrl({ url: 'pages/Detail', params: params });
  }

  // ---------- UI ----------

  @Builder
  tabButton(label: string, mode: FeedMode) {
    Text(label)
      .fontSize(15)
      .fontWeight(this.mode === mode ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.mode === mode ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .onClick(() => this.switchMode(mode))
  }

  @Builder
  comicCard(comic: KomiicComic) {
    Column() {
      KomiicImage({
        url: (comic.imageUrl ?? '').trim(),
        referer: '',
        imageFit: ImageFit.Cover
      })
        .width('100%')
        .aspectRatio(0.72)
        .clip(true)
        .borderRadius(8)

      Text((comic.title ?? '').trim())
        .fontSize(13)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })

      Text(authorLine(comic))
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 2 })

      Text(relativeUpdateText(comic.dateUpdated))
        .fontSize(10)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .width('100%')
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
    .onClick(() => this.openDetail(comic))
  }

  @Builder
  filterBar() {
    if (this.mode === FeedMode.Ranking) {
      Row() {
        ForEach(RANKING_OPTIONS, (item: LabeledOption) => {
          Text(item.label)
            .fontSize(13)
            .fontColor(this.rankingOrder === item.value
              ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .onClick(() => {
              this.rankingOrder = item.value;
              this.reload();
            })
        }, (item: LabeledOption) => item.value)
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
    } else if (this.mode === FeedMode.Category) {
      Scroll() {
        Row() {
          ForEach(CATEGORY_OPTIONS, (item: LabeledOption) => {
            Text(item.label)
              .fontSize(13)
              .fontColor(this.categoryId === item.value
                ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.categoryId = item.value;
                this.reload();
              })
          }, (item: LabeledOption) => item.value)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 12, right: 12 })
    }
  }

  build() {
    Column() {
      // 搜索框
      Row() {
        TextInput({ placeholder: '搜索漫画或作者', text: this.keyword })
          .layoutWeight(1)
          .height(38)
          .onChange((value: string) => this.keyword = value)
          .onSubmit(() => {
            if (this.keyword.trim().length === 0) {
              return;
            }
            this.mode = FeedMode.Search;
            this.reload();
          })

        Text('设置')
          .fontSize(14)
          .fontColor($r('sys.color.font_emphasize'))
          .padding({ left: 12 })
          .onClick(() => router.pushUrl({ url: 'pages/Settings' }))
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 4 })

      // tab
      Row() {
        this.tabButton('最近更新', FeedMode.Recent)
        this.tabButton('排行榜', FeedMode.Ranking)
        this.tabButton('分类', FeedMode.Category)
        if (this.mode === FeedMode.Search) {
          this.tabButton('搜索结果', FeedMode.Search)
        }
      }
      .width('100%')
      .padding({ left: 4 })

      this.filterBar()

      // 列表
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
          Button('重试')
            .margin({ top: 12 })
            .onClick(() => this.reload())
        }
        .layoutWeight(1)
        .width('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          ForEach(this.comics, (comic: KomiicComic) => {
            GridItem() {
              this.comicCard(comic)
            }
          }, (comic: KomiicComic, index: number) => (comic.id ?? '') + '_' + index.toString())

          if (this.loadingMore) {
            GridItem() {
              Row() {
                LoadingProgress().width(24).height(24)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
          }
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(10)
        .rowsGap(14)
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
        .onReachEnd(() => this.loadMore())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
