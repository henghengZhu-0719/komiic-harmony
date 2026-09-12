/**
 * Komiic 接口常量与筛选项。
 * 所有值来自 Breeze-plugin-komiic 的实测结果，改动前先确认线上行为。
 */

export const API_BASE: string = 'https://komiic.com';
export const GRAPHQL_URL: string = API_BASE + '/api/query';
export const LOGIN_URL: string = API_BASE + '/api/login';
export const IMAGE_URL_PREFIX: string = API_BASE + '/api/image/';

/** 站点会按 UA 拦截，不要改成鸿蒙默认 UA。 */
export const DEFAULT_USER_AGENT: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

export const REQUEST_TIMEOUT_MS: number = 30000;

export const SEARCH_PAGE_SIZE: number = 20;
export const CATEGORY_PAGE_SIZE: number = 30;
export const COMMENT_PAGE_SIZE: number = 100;

export interface LabeledOption {
  label: string;
  value: string;
}

export const CATEGORY_OPTIONS: LabeledOption[] = [
  { label: '全部', value: '0' },
  { label: '愛情', value: '1' },
  { label: '後宮', value: '2' },
  { label: '神鬼', value: '3' },
  { label: '校園', value: '4' },
  { label: '搞笑', value: '5' },
  { label: '生活', value: '6' },
  { label: '懸疑', value: '7' },
  { label: '冒險', value: '8' },
  { label: '恐怖', value: '9' },
  { label: '職場', value: '10' },
  { label: '魔幻', value: '11' },
  { label: '魔法', value: '12' },
  { label: '格鬥', value: '13' },
  { label: '宅男', value: '14' },
  { label: '勵志', value: '15' },
  { label: '耽美', value: '16' },
  { label: '科幻', value: '17' },
  { label: '百合', value: '18' },
  { label: '治癒', value: '19' },
  { label: '萌系', value: '20' },
  { label: '熱血', value: '21' },
  { label: '競技', value: '22' },
  { label: '推理', value: '23' },
  { label: '雜誌', value: '24' },
  { label: '偵探', value: '25' },
  { label: '偽娘', value: '26' },
  { label: '美食', value: '27' },
  { label: '四格', value: '28' },
  { label: '社會', value: '31' },
  { label: '歷史', value: '32' },
  { label: '戰爭', value: '33' },
  { label: '舞蹈', value: '34' },
  { label: '武俠', value: '35' },
  { label: '機戰', value: '36' },
  { label: '音樂', value: '37' },
  { label: '體育', value: '40' },
  { label: '黑道', value: '42' }
];

export const RANKING_OPTIONS: LabeledOption[] = [
  { label: '月榜', value: 'MONTH_VIEWS' },
  { label: '綜合', value: 'VIEWS' }
];

export const CATEGORY_SORT_OPTIONS: LabeledOption[] = [
  { label: '更新', value: 'DATE_UPDATED' },
  { label: '觀看數', value: 'VIEWS' },
  { label: '喜愛數', value: 'FAVORITE_COUNT' }
];

export const CATEGORY_STATUS_OPTIONS: LabeledOption[] = [
  { label: '全部', value: '' },
  { label: '連載中', value: 'ONGOING' },
  { label: '完結', value: 'END' }
];

export const FAVORITE_ORDER_OPTIONS: LabeledOption[] = [
  { label: '更新时间', value: 'DATE_UPDATED' },
  { label: '观看数', value: 'VIEWS' },
  { label: '收藏数', value: 'FAVORITE_COUNT' }
];

/** 单张漫画图片的请求地址。 */
export function imageUrlOf(kid: string): string {
  return IMAGE_URL_PREFIX + kid;
}

/** 图片必须带这个 Referer，否则 403。 */
export function chapterRefererOf(comicId: string, chapterId: string): string {
  return `${API_BASE}/comic/${comicId}/chapter/${chapterId}/images/all`;
}
