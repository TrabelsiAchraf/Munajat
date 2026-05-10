#!/usr/bin/env python3
"""
Build Adhkar/adhkar.json from two open-source Hisn al-Muslim datasets.

V2 improvements (2026-05-09):
- Two-phase matching: rn0x chapter -> wafa chapter (Jaccard on token sets),
  then within the matched chapter, item -> item (Jaccard).
- Replaces brittle 60-char prefix matching that gave ~48% coverage.

Sources:
  - rn0x/hisn_almuslim_json        : Arabic text + footnotes (sources, notes)
  - wafaaelmaandy/Hisn-Muslim-Json : English translation + REPEAT (count) + audio URL
"""
import json
import re
from pathlib import Path

# ---------- Manual mapping: AdhkarType case -> canonical Arabic title ----------
TYPE_TO_TITLE = {
    "wakeUp":                       "أذكار الاستيقاظ من النوم",
    "wearingClothes":               "دعاء لبس الثوب",
    "wearingNewClothes":            "دعاء لبس الثوب الجديد",
    "duaForSomeoneWearingNew":      "الدعاء لمن لبس ثوبا جديدا",
    "removingClothes":              "ما يقول إذا وضع ثوبه",
    "enterBathroom":                "دعاء دخول الخلاء",
    "leaveBathroom":                "دعاء الخروج من الخلاء",
    "beforeWudu":                   "الذكر قبل الوضوء",
    "afterWudu":                    "الذكر بعد الفراغ من الوضوء",
    "leavingHouse":                 "الذكر عند الخروج من المنزل",
    "enteringHouse":                "الذكر عند دخول المنزل",
    "goingToMosque":                "دعاء الذهاب إلى المسجد",
    "enteringMosque":               "دعاء دخول المسجد",
    "leavingMosque":                "دعاء الخروج من المسجد",
    "adhanAdhkar":                  "أذكار الأذان",
    "openingDua":                   "دعاء الاستفتاح",
    "ruku":                         "دعاء الركوع",
    "standingFromRuku":             "دعاء الرفع من الركوع",
    "sujud":                        "دعاء السجود",
    "betweenTwoSujood":             "دعاء الجلسة بين السجدتين",
    "sujudTilawa":                  "دعاء سجود التلاوة",
    "tashahhud":                    "التشهد",
    "salawatAfterTashahhud":        "الصلاة على النبي بعد التشهد",
    "afterLastTashahhud":           "الدعاء بعد التشهد الأخير قبل السلام",
    "afterPrayerAdhkar":            "الأذكار بعد السلام من الصلاة",
    "istikharahPrayer":             "دعاء صلاة الاستخارة",
    "morningAdhkar":                "أذكار الصباح",
    "eveningAdhkar":                "أذكار المساء",
    "sleepAdhkar":                  "أذكار النوم",
    "duaWhenTurningAtNight":        "الدعاء إذا تقلب ليلا",
    "nightFear":                    "دعاء الفزع في النوم ومن بلي بالوحشة",
    "dreamReaction":                "ما يفعل من رأى الرؤيا أو الحلم",
    "qunootWitr":                   "دعاء قنوت الوتر",
    "afterWitrAdhkar":              "الذكر عقب السلام من الوتر",
    "sadnessWorry":                 "دعاء الهم والحزن",
    "distress":                     "دعاء الكرب",
    "meetingEnemy":                 "دعاء لقاء العدو وذي السلطان",
    "fearUnjustRuler":              "دعاء من خاف ظلم السلطان",
    "againstEnemy":                 "الدعاء على العدو",
    "fearPeople":                   "ما يقول من خاف قوما",
    "waswasahFaith":                "دعاء من أصابه وسوسة في الإيمان",
    "debtRelief":                   "دعاء قضاء الدين",
    "waswasahPrayer":               "دعاء الوسوسة في الصلاة والقراءة",
    "hardMatter":                   "دعاء من استصعب عليه أمر",
    "repentanceAfterSin":           "ما يقول ويفعل من أذنب ذنبا",
    "expelShaytanWhispers":         "دعاء طرد الشيطان ووساوسه",
    "duaInUnwantedSituation":       "الدعاء حينما يقع ما لا يرضاه أو غلب على أمره",
    "newbornGreetingAndReply":      "تهنئة المولود له وجوابه",
    "protectionDuaForChildren":     "ما يعوذ به الأولاد",
    "duaForSickWhenVisited":        "الدعاء للمريض في عيادته",
    "virtueVisitingSick":           "فضل عيادة المريض",
    "desperateSickDua":             "دعاء المريض الذي يئس من حياته",
    "finalMomentsDua":              "تلقين المحتضر",
    "calamityDua":                  "دعاء من أصيب بمصيبة",
    "duaaWhenClosingDeadEyes":      "الدعاء عند إغماض الميت",
    "duaaForDeadInJanazah":         "الدعاء للميت في الصلاة عليه",
    "duaaForObligatoryPrayerOnDead":"الدعاء للفرط في الصلاة عليه",
    "duaaForCondolence":            "دعاء التعزية",
    "duaaWhenPuttingInGrave":       "الدعاء عند إدخال الميت القبر",
    "duaaAfterBurial":              "الدعاء بعد دفن الميت",
    "duaaVisitingGraves":           "دعاء زيارة القبور",
    "duaaForWind":                  "دعاء الريح",
    "duaaForThunder":               "دعاء الرعد",
    "askingForRain":                "من أدعية الاستسقاء",
    "whenRainFalls":                "الدعاء إذا نزل المطر",
    "afterRain":                    "الذكر بعد نزول المطر",
    "duaForClearSky":               "من أدعية الاستصحاء",
    "moonSighting":                 "دعاء رؤية الهلال",
    "iftarDua":                     "الدعاء عند إفطار الصائم",
    "beforeMeal":                   "الدعاء قبل الطعام",
    "afterMeal":                    "الدعاء عند الفراغ من الطعام",
    "guestForHost":                 "دعاء الضيف لصاحب الطعام",
    "duaForDrinkOrDesire":          "الدعاء لمن سقاه أو إذا أراد ذلك",
    "iftarAtSomeoneHome":           "الدعاء إذا أفطر عند أهل بيت",
    "fastingWithFoodButNoIftar":    "دعاء الصائم إذا حضر الطعام ولم يفطر",
    "fastingResponseToInsult":      "ما يقول الصائم إذا سابه أحد",
    "seeingDatesFirstTime":         "الدعاء عند رؤية باكورة الثمر",
    "sneezeDua":                    "دعاء العطاس",
    "responseToSneezingKafir":      "ما يقال للكافر إذا عطس فحمد الله",
    "duaForMarriedPerson":          "الدعاء للمتزوج",
    "marriageAndRidePurchase":      "دعاء المتزوج لنفسه ودعاء شراء الدابة",
    "beforeIntercourse":            "الدعاء قبل إتيان الزوجة",
    "anger":                        "دعاء الغضب",
    "whenSeeingAfflicted":          "دعاء من رأى مبتلى",
    "whatToSayInGathering":         "ما يقال في المجلس",
    "gatheringExpiation":           "كفارة المجلس",
    "replyForgiveness":             "الدعاء لمن قال غفر الله لك",
    "thanksForKindness":            "الدعاء لمن صنع إليك معروفا",
    "protectionFromDajjal":         "ما يعصم به من الدجال",
    "replyLoveForAllah":            "الدعاء لمن قال إني أحبك في الله",
    "duaaWhenSomeoneOffersWealth":  "الدعاء لمن عرض عليك ماله",
    "duaaForCreditorWhenRepaying":  "الدعاء لمن أقرض عند القضاء",
    "duaaFearOfShirk":              "دعاء الخوف من الشرك",
    "duaaForSomeoneWhoBlessedYou":  "الدعاء لمن قال بارك الله فيك",
    "duaaForSuperstitionAversion":  "دعاء كراهية الطيرة",
    "duaaForRiding":                "دعاء ركوب الدابة",
    "duaaForTravel":                "دعاء السفر",
    "duaaEnteringVillageOrTown":    "دعاء دخول القرية أو البلدة",
    "duaaEnteringMarket":           "دعاء دخول السوق",
    "ifMountStumbles":              "الدعاء إذا تعس المركوب",
    "travelerToResident":           "دعاء المسافر للمقيم",
    "residentToTraveler":           "دعاء المقيم للمسافر",
    "tasbihWhileTraveling":         "التكبير والتسبيح في سير السفر",
    "travelerAtSahar":              "دعاء المسافر إذا أسحر",
    "whenStayingSomewhere":         "الدعاء إذا نزل منزلا في سفر أو غيره",
    "returnFromTravel":             "ذكر الرجوع من السفر",
    "reactionToGoodOrBadNews":      "ما يقول ويفعل من أتاه أمر يسره أو يكرهه",
    "virtueOfSalatOnProphet":       "فضل الصلاة على النبي صلى الله عليه وسلم",
    "initiateSalam":                "إفشاء السلام",
    "replySalamToNonMuslim":        "كيف يرد السلام على الكافر إذا سلم",
    "duaWhenHearingAnimals":        "دعاء صياح الديك ونهيق الحمار",
    "duaDogBarkAtNight":            "دعاء نباح الكلاب بالليل",
    "duaForOneYouInsulted":         "الدعاء لمن سببته",
    "responseToPraise":             "ما يقول المسلم إذا مدح المسلم",
    "responseToPraiseMentioned":    "ما يقول المسلم إذا زكي",
    "talbiyahForIhram":             "كيف يلبي المحرم في الحج أو العمرة",
    "takbirAtBlackStone":           "التكبيرة إذا أتي الركن الأسود",
    "duaaBetweenRuknAndBlackStone": "الدعاء بين الركن اليماني والحجر الأسود",
    "duaaAtSafaAndMarwah":          "دعاء الوقوف على الصفا والمروة",
    "duaaOnArafatDay":              "الدعاء يوم عرفة",
    "dhikrAtMasharAlHaram":         "الذكر عند المشعر الحرام",
    "takbeerWhileThrowingStones":   "التكبيرة عند رمي الجمار مع كل حصاة",
    "duaaOfAmazementAndJoy":        "ما يقول عند التعجب والأمر السار",
    "whatToSayWhenYouReceiveGoodNews":"ما يفعل من أتاه أمر يسره",
    "duaaWhenFeelingPain":          "ما يقول من أحس وجعا في جسده",
    "duaaIfYouFearToHarmWithEye":   "دعاء من خشي أن يصيب شيئا بعينه",
    "whatToSayWhenFrightened":      "ما يقال عند الفزع",
    "whatToSayWhenSlaughtering":    "ما يقول عند الذبح أو النحر",
    "whatToSayAgainstDevils":       "ما يقول لرد كيد مردة الشياطين",
    "forgivenessAndRepentance":     "الاستغفار والتوبة",
    "virtueOfDhikrForms":           "فضل التسبيح والتحميد والتهليل والتكبير",
    "howProphetDidTasbih":          "كيف كان النبي يسبح",
    "generalGoodEtiquette":         "من أنواع الخير والآداب الجامعة",
}

SECTION = {
    "daily":       {"wakeUp", "sleepAdhkar", "morningAdhkar", "eveningAdhkar",
                    "duaWhenTurningAtNight", "nightFear", "dreamReaction",
                    "wearingClothes", "wearingNewClothes", "duaForSomeoneWearingNew",
                    "removingClothes", "enterBathroom", "leaveBathroom",
                    "leavingHouse", "enteringHouse",
                    "duaWhenHearingAnimals", "duaDogBarkAtNight"},
    "prayer":      {"beforeWudu", "afterWudu", "goingToMosque", "enteringMosque",
                    "leavingMosque", "adhanAdhkar", "openingDua", "ruku",
                    "standingFromRuku", "sujud", "betweenTwoSujood", "sujudTilawa",
                    "tashahhud", "salawatAfterTashahhud", "afterLastTashahhud",
                    "afterPrayerAdhkar", "istikharahPrayer", "qunootWitr",
                    "afterWitrAdhkar", "waswasahPrayer"},
    "eating":      {"iftarDua", "beforeMeal", "afterMeal", "guestForHost",
                    "duaForDrinkOrDesire", "iftarAtSomeoneHome",
                    "fastingWithFoodButNoIftar", "fastingResponseToInsult",
                    "seeingDatesFirstTime"},
    "travel":      {"duaaForRiding", "duaaForTravel", "duaaEnteringVillageOrTown",
                    "duaaEnteringMarket", "ifMountStumbles", "travelerToResident",
                    "residentToTraveler", "tasbihWhileTraveling", "travelerAtSahar",
                    "whenStayingSomewhere", "returnFromTravel"},
    "hajj":        {"talbiyahForIhram", "takbirAtBlackStone",
                    "duaaBetweenRuknAndBlackStone", "duaaAtSafaAndMarwah",
                    "duaaOnArafatDay", "dhikrAtMasharAlHaram",
                    "takbeerWhileThrowingStones"},
    "funerals":    {"duaaWhenClosingDeadEyes", "duaaForDeadInJanazah",
                    "duaaForObligatoryPrayerOnDead", "duaaForCondolence",
                    "duaaWhenPuttingInGrave", "duaaAfterBurial",
                    "duaaVisitingGraves", "calamityDua", "finalMomentsDua",
                    "desperateSickDua"},
    "weather":     {"duaaForWind", "duaaForThunder", "askingForRain",
                    "whenRainFalls", "afterRain", "duaForClearSky",
                    "moonSighting"},
    "social":      {"sneezeDua", "responseToSneezingKafir", "duaForMarriedPerson",
                    "marriageAndRidePurchase", "beforeIntercourse", "anger",
                    "whenSeeingAfflicted", "whatToSayInGathering",
                    "gatheringExpiation", "replyForgiveness", "thanksForKindness",
                    "replyLoveForAllah", "duaaWhenSomeoneOffersWealth",
                    "duaaForCreditorWhenRepaying", "duaaForSomeoneWhoBlessedYou",
                    "initiateSalam", "replySalamToNonMuslim", "duaForOneYouInsulted",
                    "responseToPraise", "responseToPraiseMentioned",
                    "newbornGreetingAndReply"},
    "protection":  {"protectionFromDajjal", "protectionDuaForChildren",
                    "expelShaytanWhispers", "againstEnemy", "fearUnjustRuler",
                    "meetingEnemy", "fearPeople", "waswasahFaith", "hardMatter",
                    "repentanceAfterSin", "duaInUnwantedSituation", "debtRelief",
                    "duaaFearOfShirk", "duaaForSuperstitionAversion",
                    "duaaIfYouFearToHarmWithEye", "whatToSayWhenFrightened",
                    "whatToSayAgainstDevils", "duaaOfAmazementAndJoy",
                    "whatToSayWhenYouReceiveGoodNews", "reactionToGoodOrBadNews"},
    "healing":     {"duaForSickWhenVisited", "virtueVisitingSick",
                    "duaaWhenFeelingPain", "sadnessWorry", "distress"},
    "other":       {"whatToSayWhenSlaughtering", "forgivenessAndRepentance",
                    "virtueOfDhikrForms", "howProphetDidTasbih",
                    "generalGoodEtiquette", "virtueOfSalatOnProphet"},
}
def section_of(case_name):
    for sec, members in SECTION.items():
        if case_name in members:
            return sec
    return "other"

# ---------- Arabic normalization & tokenisation ----------
DIACRITICS = re.compile(r'[ً-ٰٟۖ-ۭ]')
TATWEEL = re.compile(r'ـ')

def norm_ar(s: str) -> str:
    if not s:
        return ""
    s = DIACRITICS.sub('', s)
    s = TATWEEL.sub('', s)
    s = (s.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
           .replace('ى', 'ي').replace('ئ', 'ي').replace('ؤ', 'و')
           .replace('ة', 'ه'))
    s = re.sub(r'\s+', ' ', s).strip()
    s = re.sub(r'[^؀-ۿ\s]', '', s)
    return s

# Stop-word-ish: very short tokens that match too easily
SHORT_STOP = {"و", "في", "من", "ما", "لا", "هو", "ال", "اله", "الله", "يا", "ان", "اذا", "علي"}

def tokens(s: str) -> set:
    if not s:
        return set()
    return {t for t in norm_ar(s).split() if len(t) >= 3 and t not in SHORT_STOP}

def jaccard(a: set, b: set) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)

# ---------- Load sources ----------
RN0X = json.loads(Path('/tmp/hisn_ar.json').read_text(encoding='utf-8'))
WAFA = json.loads(Path('/tmp/husn_en.json').read_text(encoding='utf-8-sig'))['English']

# ---------- Phase 1: build rn0x_chapter -> wafa_chapter mapping ----------
WAFA_TOKENS = []  # list of (chapter, token_set)
for w_ch in WAFA:
    toks = set()
    for it in w_ch.get('TEXT', []) or []:
        toks |= tokens(it.get('ARABIC_TEXT', ''))
    WAFA_TOKENS.append((w_ch, toks))

CHAPTER_MAPPING = {}  # rn_key -> (wafa_chapter, score)
for rn_key, rn_ch in RN0X.items():
    rn_toks = set()
    for text in rn_ch.get('text', []) or []:
        rn_toks |= tokens(text)
    if not rn_toks:
        continue
    best = (None, 0.0)
    for w_ch, w_toks in WAFA_TOKENS:
        s = jaccard(rn_toks, w_toks)
        if s > best[1]:
            best = (w_ch, s)
    if best[0] and best[1] >= 0.15:
        CHAPTER_MAPPING[rn_key] = best

# ---------- Phase 2: per-chapter rn0x_item -> wafa_item ----------
def match_item_in_chapter(rn_text: str, wafa_chapter) -> "dict | None":
    rn_toks = tokens(rn_text)
    if not rn_toks:
        return None
    best = (None, 0.0)
    for it in wafa_chapter.get('TEXT', []) or []:
        s = jaccard(rn_toks, tokens(it.get('ARABIC_TEXT', '')))
        if s > best[1]:
            best = (it, s)
    return best[0] if best[1] >= 0.20 else None

# ---------- Manual rn0x overrides for fuzzy chapter titles ----------
RN0X_OVERRIDES = {
    "removingClothes":         "ما يقول إذا وضع الثوب",
    "enteringHouse":           "الذكر عند الدخول المنزل",
    "morningAdhkar":           "أذكار الصباح والمساء",
    "eveningAdhkar":           "أذكار الصباح والمساء",
    "nightFear":               "دعاء القلق والفزع في النوم ومن بلي بالوحشة",
    "waswasahFaith":           "دعاء من أصابه شك في الإيمان",
    "duaInUnwantedSituation":  "الدعاء حينما يقع مالا يرضاه أو غلب على أمره",
    "virtueOfDhikrForms":      "فضل التسبيح والتحميد ، والتهليل ، والتكبير",
    "howProphetDidTasbih":     "كيف كان النبي صلى الله عليه وسلم يسبح ؟",
}

rn0x_by_norm = {norm_ar(k): k for k in RN0X.keys()}

def find_rn0x(arabic_title: str, case_name: str = "") -> "str | None":
    if case_name in RN0X_OVERRIDES:
        return RN0X_OVERRIDES[case_name]
    nt = norm_ar(arabic_title)
    if nt in rn0x_by_norm:
        return rn0x_by_norm[nt]
    for nk, k in rn0x_by_norm.items():
        if nt in nk or nk in nt:
            return k
    return None

# ---------- Build categories ----------
def case_to_id(case_name: str) -> str:
    return re.sub(r'(?<!^)(?=[A-Z])', '_', case_name).lower()

ORDER_LIST = list(TYPE_TO_TITLE.keys())
categories = []
items_with_audio = items_with_translation = 0

for idx, case in enumerate(ORDER_LIST):
    ar_title = TYPE_TO_TITLE[case]
    rn_key = find_rn0x(ar_title, case)
    cat = {
        "id": case_to_id(case),
        "type": case,
        "order": idx + 1,
        "section": section_of(case),
        "title": {"ar": ar_title},
        "items": []
    }
    if rn_key is None:
        categories.append(cat)
        continue

    rn_ch = RN0X[rn_key]
    texts = rn_ch.get('text', []) or []
    footnotes = rn_ch.get('footnote', []) or []
    sources = [f.strip() for f in footnotes if isinstance(f, str) and not f.lstrip().startswith('*')]

    wafa_ch_info = CHAPTER_MAPPING.get(rn_key)
    wafa_ch = wafa_ch_info[0] if wafa_ch_info else None

    for i, text in enumerate(texts):
        if not isinstance(text, str) or not text.strip():
            continue
        item = {
            "id": f"{cat['id']}_{i+1}",
            "arabic": text.strip(),
            "source": sources[i] if i < len(sources) else (sources[0] if sources else ""),
            "count": 1,
        }
        if wafa_ch is not None:
            w_it = match_item_in_chapter(text, wafa_ch)
            if w_it:
                tr = (w_it.get('TRANSLATED_TEXT') or '').strip()
                if tr:
                    item["translation"] = {"en": tr}
                    items_with_translation += 1
                rep = w_it.get('REPEAT')
                if isinstance(rep, int) and rep > 0:
                    item["count"] = rep
                elif isinstance(rep, str) and rep.strip().isdigit():
                    item["count"] = int(rep.strip())
                au = w_it.get('AUDIO')
                if au and isinstance(au, str) and au.startswith("http"):
                    item["audio"] = au
                    items_with_audio += 1
        cat["items"].append(item)
    categories.append(cat)

# ---------- Output ----------
out = {"version": 1, "categories": categories}
out_path = Path('/Users/a.trabelsi/Workspace/Perso/Adhkar/Adhkar/adhkar.json')
out_path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')

total_items = sum(len(c['items']) for c in categories)
mapped_chapters = sum(1 for c in categories if any(it.get('audio') or it.get('translation') for it in c['items']))
print(f"Wrote {out_path}")
print(f"Total categories: {len(categories)}, items: {total_items}")
print(f"Items with audio:        {items_with_audio} ({100*items_with_audio/total_items:.0f}%)")
print(f"Items with translation:  {items_with_translation} ({100*items_with_translation/total_items:.0f}%)")
print(f"Categories that got >=1 wafa enrichment: {mapped_chapters}")
print(f"Chapter-level mapping (rn0x->wafa): {len(CHAPTER_MAPPING)}/{len(RN0X)} chapters")
