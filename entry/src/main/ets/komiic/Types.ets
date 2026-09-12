/**
 * Komiic GraphQL 的显式类型定义。
 * ArkTS 不允许 any/unknown，所以每个响应都要有确定的 interface。
 */

// ---------- 实体 ----------

export interface KomiicAuthor {
  id?: string;
  name?: string;
}

export interface KomiicCategory {
  id?: string;
  name?: string;
}

export interface KomiicComic {
  id?: string;
  title?: string;
  status?: string;
  imageUrl?: string;
  authors?: KomiicAuthor[];
  categories?: KomiicCategory[];
  dateUpdated?: string;
  monthViews?: number;
  views?: number;
  favoriteCount?: number;
  lastChapterUpdate?: string;
}

/** comicByIds 的精简投影，只用于推荐位。 */
export interface KomiicComicBasic {
  id?: string;
  title?: string;
  imageUrl?: string;
}

export interface KomiicChapter {
  id?: string;
  serial?: string;
  /** 'book' 表示单行本，展示成「卷 N」。 */
  type?: string;
  dateUpdated?: string;
}

export interface KomiicImage {
  id?: string;
  /** 真正用于拼图片地址的 key。 */
  kid?: string;
  height?: number;
  width?: number;
}

export interface KomiicFolder {
  id?: string;
  key?: string;
  name?: string;
  comicCount?: number;
  dateUpdated?: string;
}

export interface KomiicAccount {
  id?: string;
  nickname?: string;
  profileImageUrl?: string;
}

export interface KomiicReplyRef {
  id?: string;
}

export interface KomiicComment {
  id?: string;
  comicId?: string;
  account?: KomiicAccount;
  message?: string;
  replyTo?: KomiicReplyRef;
  dateUpdated?: string;
  dateCreated?: string;
}

export interface KomiicSearchResult {
  comics?: KomiicComic[];
  authors?: KomiicAuthor[];
}

export interface KomiicFolderComicIds {
  comicIds?: string[];
}

export interface KomiicCreatedFolder {
  id?: string;
  name?: string;
}

// ---------- GraphQL 信封 ----------

export interface GraphQlError {
  message?: string;
}

export interface GraphQlResponse<T> {
  data?: T;
  errors?: GraphQlError[];
}

export interface GraphQlRequest<V> {
  operationName: string;
  variables: V;
  query: string;
}

// ---------- 请求变量 ----------

export interface Pagination {
  limit: number;
  offset: number;
  orderBy: string;
  status?: string;
  asc: boolean;
}

export interface PaginationVars {
  pagination: Pagination;
}

export interface KeywordVars {
  keyword: string;
}

export interface ComicIdVars {
  comicId: string;
}

export interface ComicIdsVars {
  comicIds: string[];
}

export interface ChapterIdVars {
  chapterId: string;
}

export interface CategoryVars {
  categoryId: string[];
  pagination: Pagination;
}

export interface FolderPageVars {
  folderId: string;
  pagination: Pagination;
}

export interface FolderMutationVars {
  comicId: string;
  folderId: string;
}

export interface CreateFolderVars {
  name: string;
}

export interface MessagePageVars {
  comicId: string;
  pagination: Pagination;
}

export interface MessageIdVars {
  messageId: string;
}

export type EmptyVars = Record<string, string>;

// ---------- 各操作的 data 形状 ----------

export interface RecentUpdateData {
  recentUpdate?: KomiicComic[];
}

export interface HotComicsData {
  hotComics?: KomiicComic[];
}

export interface SearchData {
  searchComicsAndAuthors?: KomiicSearchResult;
}

export interface ComicByIdsData {
  comicByIds?: KomiicComic[];
}

export interface ComicBasicByIdsData {
  comicByIds?: KomiicComicBasic[];
}

export interface RecommendData {
  recommendComicById?: string[];
}

export interface ChaptersData {
  chaptersByComicId?: KomiicChapter[];
}

export interface ImagesData {
  imagesByChapterId?: KomiicImage[];
}

export interface CategoriesData {
  comicByCategories?: KomiicComic[];
}

export interface FoldersData {
  folders?: KomiicFolder[];
}

export interface ComicInFoldersData {
  comicInAccountFolders?: string[];
}

export interface FolderComicIdsData {
  folderComicIds?: KomiicFolderComicIds;
}

export interface AddToFolderData {
  addComicToFolder?: boolean;
}

export interface RemoveFromFolderData {
  removeComicToFolder?: boolean;
}

export interface CreateFolderData {
  createFolder?: KomiicCreatedFolder;
}

export interface MessagesData {
  getMessagesByComicId?: KomiicComment[];
}

export interface MessageChanData {
  messageChan?: KomiicComment[];
}

export interface MessageCountData {
  messageCountByComicId?: number;
}

// ---------- REST ----------

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  token?: string;
  message?: string;
  error?: string;
  errmsg?: string;
  msg?: string;
  errors?: GraphQlError[];
}

// ---------- 页面用的视图模型 ----------

/** 章节在 UI 里的统一形状，已经处理好「卷 N / 第 N 话」。 */
export interface ChapterRef {
  id: string;
  name: string;
  order: number;
  serial: string;
  type: string;
  updatedAt: string;
}

/** 阅读页的一页。 */
export interface PageRef {
  id: string;
  url: string;
  referer: string;
  index: number;
}
