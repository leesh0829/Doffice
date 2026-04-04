export interface PluginRegistryEntry {
  id: string;
  name: string;
  author: string;
  description: string;
  version: string;
  downloadURL: string;
  characterCount: number;
  tags: string[];
  stars: number;
}

export const pluginRegistry: PluginRegistryEntry[] = [
  {
    id: "flea-market-hidden-pack",
    name: "플리 마켓 히든 캐릭터 팩",
    author: "WorkMan",
    description: "플리 마켓에서 바로 고용할 수 있는 히든 캐릭터 3종을 추가합니다.",
    version: "1.0.0",
    downloadURL: "https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/plugins/flea-market-hidden-pack/plugin.json",
    characterCount: 3,
    tags: ["hidden", "market", "characters"],
    stars: 42
  },
  {
    id: "typing-combo-pack",
    name: "타이핑 콤보 팩",
    author: "WorkMan",
    description: "터미널 외부에서 타이핑할 때 콤보 카운터, 파티클, 화면 흔들림 이펙트가 발동합니다.",
    version: "1.0.0",
    downloadURL: "https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/plugins/typing-combo-pack/plugin.json",
    characterCount: 0,
    tags: ["effects", "combo", "typing", "particles"],
    stars: 128
  },
  {
    id: "premium-furniture-pack",
    name: "프리미엄 가구 팩",
    author: "WorkMan",
    description: "아쿠아리움, 아케이드 머신, 네온사인, 빈백, 관엽식물 등 프리미엄 가구 8종을 추가합니다.",
    version: "1.0.0",
    downloadURL: "https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/plugins/premium-furniture-pack/plugin.json",
    characterCount: 0,
    tags: ["furniture", "decoration", "premium", "office"],
    stars: 95
  },
  {
    id: "vacation-beach-pack",
    name: "바캉스 비치 팩",
    author: "WorkMan",
    description: "사무실을 해변으로 변신! 야자수, 서핑보드, 파라솔 아래에서 코딩하는 바캉스 컨셉 오피스.",
    version: "1.0.0",
    downloadURL: "https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/plugins/vacation-beach-pack/plugin.json",
    characterCount: 2,
    tags: ["theme", "beach", "vacation", "tropical", "office-preset"],
    stars: 210
  },
  {
    id: "battleground-pack",
    name: "배틀그라운드 팩",
    author: "WorkMan",
    description: "사무실이 전장으로! 나무, 바위, 수풀에 숨어 코딩하는 배그 컨셉 오피스. 에어드랍 이펙트 포함.",
    version: "1.0.0",
    downloadURL: "https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/plugins/battleground-pack/plugin.json",
    characterCount: 3,
    tags: ["theme", "battleground", "military", "survival", "office-preset"],
    stars: 187
  }
];
