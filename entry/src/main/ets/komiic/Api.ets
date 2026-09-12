/**
 * Komiic 的全部业务接口。
 *
 * query 字符串与 Breeze-plugin-komiic 完全一致，是实测可用的版本，不要「优化」字段。
 * 标了「需登录」的会先走 ensureAuthenticated。
 */

import { CATEGORY_PAGE_SIZE, COMMENT_PAGE_SIZE, SEARCH_PAGE_SIZE } from './Config';
import { KomiicClient } from './Client';
import {
  AddToFolderData,
  CategoriesData,
  CategoryVars,
  ChapterIdVars,
  ChapterRef,
  ChaptersData,
  ComicBasicByIdsData,
  ComicByIdsData,
  ComicIdVars,
  ComicIdsVars,
  ComicInFoldersData,
  CreateFolderData,
  CreateFolderVars,
  EmptyVars,
  FolderComicIdsData,
  FolderPageVars,
  FolderMutationVars,
  FoldersData,
  GraphQlRequest,
  HotComicsData,
  ImagesData,
  KeywordVars,
  KomiicChapter,
  KomiicComic,
  KomiicComicBasic,
  KomiicComment,
  KomiicCreatedFolder,
  KomiicFolder,
  KomiicImage,
  KomiicSearchResult,
  MessageChanData,
  MessageCountData,
  MessageIdVars,
  MessagePageVars,
  MessagesData,
  Pagination,
  PaginationVars,
  RecentUpdateData,
  RecommendData,
  SearchData
} from './Types';

/** 列表接口的公共字段，抽出来避免抄错。 */
const COMIC_FIELDS: string = `
  id
  title
  status
  imageUrl
  authors { id name }
  categories { id name }
  dateUpdated
  monthViews
  views
  favoriteCount
  lastChapterUpdate
`;

function pageOffset(page: number, size: number): number {
  return (Math.max(1, page) - 1) * size;
}

function uniqueIds(ids: string[]): string[] {
  const seen: Set<string> = new Set<string>();
  const result: string[] = [];
  ids.forEach((raw: string) => {
    const id = (raw ?? '').trim();
    if (id.length > 0 && !seen.has(id)) {
      seen.add(id);
      result.push(id);
    }
  });
  return result;
}

export class KomiicApi {
  private client: KomiicClient;

  constructor(client: KomiicClient) {
    this.client = client;
  }

  // ================= 列表 =================

  /** 最近更新。 */
  async recentUpdate(page: number): Promise<KomiicComic[]> {
    const pagination: Pagination = {
      limit: SEARCH_PAGE_SIZE,
      offset: pageOffset(page, SEARCH_PAGE_SIZE),
      orderBy: 'DATE_UPDATED',
      status: '',
      asc: true
    };
    const request: GraphQlRequest<PaginationVars> = {
      operationName: 'recentUpdate',
      variables: { pagination: pagination },
      query: `query recentUpdate($pagination: Pagination!) {
        recentUpdate(pagination: $pagination) {${COMIC_FIELDS}}
      }`
    };
    const data = await this.client.graphql<RecentUpdateData, PaginationVars>(request, true);
    return data.recentUpdate ?? [];
  }

  /** 排行榜。orderBy: MONTH_VIEWS | VIEWS */
  async hotComics(page: number, orderBy: string): Promise<KomiicComic[]> {
    const pagination: Pagination = {
      limit: SEARCH_PAGE_SIZE,
      offset: pageOffset(page, SEARCH_PAGE_SIZE),
      orderBy: orderBy,
      status: '',
      asc: true
    };
    const request: GraphQlRequest<PaginationVars> = {
      operationName: 'hotComics',
      variables: { pagination: pagination },
      query: `query hotComics($pagination: Pagination!) {
        hotComics(pagination: $pagination) {${COMIC_FIELDS}}
      }`
    };
    const data = await this.client.graphql<HotComicsData, PaginationVars>(request, true);
    return data.hotComics ?? [];
  }

  /** 分类。categoryId 传 '0' 表示全部。 */
  async comicByCategories(
    page: number,
    categoryId: string,
    orderBy: string,
    status: string
  ): Promise<KomiicComic[]> {
    const pagination: Pagination = {
      limit: CATEGORY_PAGE_SIZE,
      offset: pageOffset(page, CATEGORY_PAGE_SIZE),
      orderBy: orderBy,
      asc: false,
      status: status
    };
    const ids: string[] = (categoryId.length > 0 && categoryId !== '0') ? [categoryId] : [];
    const request: GraphQlRequest<CategoryVars> = {
      operationName: 'comicByCategories',
      variables: { categoryId: ids, pagination: pagination },
      query: `query comicByCategories($categoryId: [ID!]!, $pagination: Pagination!) {
        comicByCategories(categoryId: $categoryId, pagination: $pagination) {${COMIC_FIELDS}}
      }`
    };
    const data = await this.client.graphql<CategoriesData, CategoryVars>(request, true);
    return data.comicByCategories ?? [];
  }

  /** 搜索。注意：服务端一次返回全部结果，没有分页。 */
  async search(keyword: string): Promise<KomiicSearchResult> {
    const request: GraphQlRequest<KeywordVars> = {
      operationName: 'searchComicAndAuthorQuery',
      variables: { keyword: keyword },
      query: `query searchComicAndAuthorQuery($keyword: String!) {
        searchComicsAndAuthors(keyword: $keyword) {
          comics {${COMIC_FIELDS}}
          authors { id name comicCount }
        }
      }`
    };
    const data = await this.client.graphql<SearchData, KeywordVars>(request, true);
    return data.searchComicsAndAuthors ?? {};
  }

  // ================= 详情 =================

  /** 按 id 批量取漫画（完整字段）。 */
  async comicByIds(ids: string[]): Promise<KomiicComic[]> {
    const list = uniqueIds(ids);
    if (list.length === 0) {
      return [];
    }
    const request: GraphQlRequest<ComicIdsVars> = {
      operationName: 'comicByIds',
      variables: { comicIds: list },
      query: `query comicByIds($comicIds: [ID]!) {
        comicByIds(comicIds: $comicIds) {${COMIC_FIELDS}}
      }`
    };
    const data = await this.client.graphql<ComicByIdsData, ComicIdsVars>(request, true);
    return data.comicByIds ?? [];
  }

  /** 按 id 批量取漫画（只要封面和标题，推荐位用）。 */
  async comicBasicsByIds(ids: string[]): Promise<KomiicComicBasic[]> {
    const list = uniqueIds(ids);
    if (list.length === 0) {
      return [];
    }
    const request: GraphQlRequest<ComicIdsVars> = {
      operationName: 'comicByIds',
      variables: { comicIds: list },
      query: `query comicByIds($comicIds: [ID]!) {
        comicByIds(comicIds: $comicIds) {
          id
          title
          imageUrl
        }
      }`
    };
    const data = await this.client.graphql<ComicBasicByIdsData, ComicIdsVars>(request, true);
    return data.comicByIds ?? [];
  }

  /** 单本漫画，找不到就抛错。 */
  async comicById(comicId: string): Promise<KomiicComic> {
    const list = await this.comicByIds([comicId]);
    for (let i = 0; i < list.length; i++) {
      if ((list[i].id ?? '').trim() === comicId) {
        return list[i];
      }
    }
    if (list.length > 0) {
      return list[0];
    }
    throw new Error('未找到漫画详情');
  }

  /** 推荐漫画的 id 列表。 */
  async recommendComicById(comicId: string): Promise<string[]> {
    const request: GraphQlRequest<ComicIdVars> = {
      operationName: 'recommendComicById',
      variables: { comicId: comicId },
      query: `query recommendComicById($comicId: ID!) {
        recommendComicById(comicId: $comicId)
      }`
    };
    const data = await this.client.graphql<RecommendData, ComicIdVars>(request, true);
    return uniqueIds(data.recommendComicById ?? []);
  }

  /** 章节列表（原始）。 */
  async chaptersByComicId(comicId: string): Promise<KomiicChapter[]> {
    const request: GraphQlRequest<ComicIdVars> = {
      operationName: 'chapterByComicId',
      variables: { comicId: comicId },
      query: `query chapterByComicId($comicId: ID!) {
        chaptersByComicId(comicId: $comicId) {
          id
          serial
          type
          dateUpdated
        }
      }`
    };
    const data = await this.client.graphql<ChaptersData, ComicIdVars>(request, true);
    return data.chaptersByComicId ?? [];
  }

  /** 章节列表（已处理成 UI 用的形状）。 */
  async chapterRefs(comicId: string): Promise<ChapterRef[]> {
    const raw = await this.chaptersByComicId(comicId);
    const refs: ChapterRef[] = [];
    raw.forEach((item: KomiicChapter, index: number) => {
      const id = (item.id ?? '').trim();
      if (id.length === 0) {
        return;
      }
      const serial = (item.serial ?? '').trim();
      const type = (item.type ?? '').trim();
      const name = type === 'book'
        ? `卷${serial}`
        : (serial.length > 0 ? serial : `第${index + 1}话`);
      const ref: ChapterRef = {
        id: id,
        name: name,
        order: index + 1,
        serial: serial,
        type: type,
        updatedAt: item.dateUpdated ?? ''
      };
      refs.push(ref);
    });
    return refs;
  }

  /** 某一章的图片。 */
  async imagesByChapterId(chapterId: string): Promise<KomiicImage[]> {
    const request: GraphQlRequest<ChapterIdVars> = {
      operationName: 'imagesByChapterId',
      variables: { chapterId: chapterId },
      query: `query imagesByChapterId($chapterId: ID!) {
        imagesByChapterId(chapterId: $chapterId) {
          id
          kid
          height
          width
        }
      }`
    };
    const data = await this.client.graphql<ImagesData, ChapterIdVars>(request, true);
    return data.imagesByChapterId ?? [];
  }

  // ================= 收藏（需登录）=================

  /** 我的收藏夹。 */
  async folders(): Promise<KomiicFolder[]> {
    await this.client.ensureAuthenticated();
    const request: GraphQlRequest<EmptyVars> = {
      operationName: 'myFolder',
      variables: {},
      query: `query myFolder {
        folders {
          id
          key
          name
          comicCount
          dateUpdated
        }
      }`
    };
    const data = await this.client.graphql<FoldersData, EmptyVars>(request, false);
    return data.folders ?? [];
  }

  /** 某本漫画在哪些收藏夹里。返回空数组即未收藏。 */
  async comicInAccountFolders(comicId: string): Promise<string[]> {
    await this.client.ensureAuthenticated();
    const request: GraphQlRequest<ComicIdVars> = {
      operationName: 'comicInAccountFolders',
      variables: { comicId: comicId },
      query: `query comicInAccountFolders($comicId: ID!) {
        comicInAccountFolders(comicId: $comicId)
      }`
    };
    const data = await this.client.graphql<ComicInFoldersData, ComicIdVars>(request, false);
    return uniqueIds(data.comicInAccountFolders ?? []);
  }

  /** 收藏夹里的漫画 id，顺序即服务端排序，后续要靠它还原。 */
  async folderComicIds(page: number, folderId: string, orderBy: string): Promise<string[]> {
    await this.client.ensureAuthenticated();
    const pagination: Pagination = {
      limit: CATEGORY_PAGE_SIZE,
      offset: pageOffset(page, CATEGORY_PAGE_SIZE),
      orderBy: orderBy,
      status: '',
      asc: true
    };
    const request: GraphQlRequest<FolderPageVars> = {
      operationName: 'folderComicIds',
      variables: { folderId: folderId, pagination: pagination },
      query: `query folderComicIds($folderId: ID!, $pagination: Pagination!) {
        folderComicIds(folderId: $folderId, pagination: $pagination) {
          comicIds
        }
      }`
    };
    const data = await this.client.graphql<FolderComicIdsData, FolderPageVars>(request, false);
    const holder = data.folderComicIds;
    return uniqueIds(holder === undefined ? [] : (holder.comicIds ?? []));
  }

  /**
   * 收藏夹内容。comicByIds 不保证顺序，所以按 id 列表重排。
   */
  async folderComics(page: number, folderId: string, orderBy: string): Promise<KomiicComic[]> {
    const ids = await this.folderComicIds(page, folderId, orderBy);
    if (ids.length === 0) {
      return [];
    }
    const comics = await this.comicByIds(ids);
    const rank: Map<string, number> = new Map<string, number>();
    ids.forEach((id: string, index: number) => rank.set(id, index));
    return comics.sort((a: KomiicComic, b: KomiicComic): number => {
      const ai = rank.get((a.id ?? '').trim()) ?? Number.MAX_SAFE_INTEGER;
      const bi = rank.get((b.id ?? '').trim()) ?? Number.MAX_SAFE_INTEGER;
      return ai - bi;
    });
  }

  async addComicToFolder(comicId: string, folderId: string): Promise<void> {
    await this.client.ensureAuthenticated();
    const request: GraphQlRequest<FolderMutationVars> = {
      operationName: 'addComicToFolder',
      variables: { comicId: comicId, folderId: folderId },
      query: `mutation addComicToFolder($comicId: ID!, $folderId: ID!) {
        addComicToFolder(comicId: $comicId, folderId: $folderId)
      }`
    };
    await this.client.graphql<AddToFolderData, FolderMutationVars>(request, false);
  }

  /** 注意服务端的拼写是 removeComicToFolder，不是 From。 */
  async removeComicFromFolder(comicId: string, folderId: string): Promise<void> {
    await this.client.ensureAuthenticated();
    const request: GraphQlRequest<FolderMutationVars> = {
      operationName: 'removeComicToFolder',
      variables: { comicId: comicId, folderId: folderId },
      query: `mutation removeComicToFolder($comicId: ID!, $folderId: ID!) {
        removeComicToFolder(comicId: $comicId, folderId: $folderId)
      }`
    };
    await this.client.graphql<RemoveFromFolderData, FolderMutationVars>(request, false);
  }

  async createFolder(name: string): Promise<KomiicCreatedFolder> {
    await this.client.ensureAuthenticated();
    const request: GraphQlRequest<CreateFolderVars> = {
      operationName: 'createFolder',
      variables: { name: name },
      query: `mutation createFolder($name: String!) {
        createFolder(name: $name) {
          id
          name
        }
      }`
    };
    const data = await this.client.graphql<CreateFolderData, CreateFolderVars>(request, false);
    return data.createFolder ?? {};
  }

  /**
   * 收藏 / 取消收藏。
   * 收藏时用第一个收藏夹，没有就建一个；取消时从所有收藏夹里移除。
   */
  async toggleFavorite(comicId: string, currentFavorite: boolean): Promise<boolean> {
    if (!currentFavorite) {
      let folders = await this.folders();
      if (folders.length === 0) {
        const created = await this.createFolder('默认收藏夹');
        const createdId = (created.id ?? '').trim();
        if (createdId.length === 0) {
          throw new Error('创建默认收藏夹失败');
        }
        folders = [{ id: createdId, name: '默认收藏夹' }];
      }
      const targetId = (folders[0].id ?? '').trim();
      if (targetId.length === 0) {
        throw new Error('未找到可用收藏夹');
      }
      await this.addComicToFolder(comicId, targetId);
      return true;
    }

    const folderIds = await this.comicInAccountFolders(comicId);
    for (let i = 0; i < folderIds.length; i++) {
      await this.removeComicFromFolder(comicId, folderIds[i]);
    }
    return false;
  }

  // ================= 评论 =================

  async commentsByComicId(comicId: string, page: number): Promise<KomiicComment[]> {
    const pagination: Pagination = {
      limit: COMMENT_PAGE_SIZE,
      offset: pageOffset(page, COMMENT_PAGE_SIZE),
      orderBy: 'DATE_UPDATED',
      asc: true
    };
    const request: GraphQlRequest<MessagePageVars> = {
      operationName: 'getMessagesByComicId',
      variables: { comicId: comicId, pagination: pagination },
      query: `query getMessagesByComicId($comicId: ID!, $pagination: Pagination!) {
        getMessagesByComicId(comicId: $comicId, pagination: $pagination) {
          id
          comicId
          account { id nickname profileImageUrl }
          message
          replyTo { id }
          dateUpdated
          dateCreated
        }
      }`
    };
    const data = await this.client.graphql<MessagesData, MessagePageVars>(request, true);
    return data.getMessagesByComicId ?? [];
  }

  /** 某条评论的回复串。 */
  async commentReplies(commentId: string): Promise<KomiicComment[]> {
    const request: GraphQlRequest<MessageIdVars> = {
      operationName: 'messageChan',
      variables: { messageId: commentId },
      query: `query messageChan($messageId: ID!) {
        messageChan(messageId: $messageId) {
          id
          comicId
          account { id nickname profileImageUrl }
          message
          replyTo { id }
          dateUpdated
          dateCreated
        }
      }`
    };
    const data = await this.client.graphql<MessageChanData, MessageIdVars>(request, true);
    return data.messageChan ?? [];
  }

  async commentCount(comicId: string): Promise<number> {
    const request: GraphQlRequest<ComicIdVars> = {
      operationName: 'messageCountByComicId',
      variables: { comicId: comicId },
      query: `query messageCountByComicId($comicId: ID!) {
        messageCountByComicId(comicId: $comicId)
      }`
    };
    const data = await this.client.graphql<MessageCountData, ComicIdVars>(request, true);
    return data.messageCountByComicId ?? 0;
  }
}
