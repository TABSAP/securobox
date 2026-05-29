# Content Rating (IARC) — exact answers

Path: **Policy and programs → App content → Content ratings → Start questionnaire**

This documents the **current** Play Console IARC questionnaire (verified May 2026). The
flow has three screens: Category → Questionnaire → Summary.

---

## Screen 1 — Category

Play Console offers only **three** top-level categories (the old
"Reference / News / Educational" sub-list was retired):

| Field | Answer |
|---|---|
| Email address | info@tabsap.com |
| Category | **All Other App Types** |
| Terms | ☑ Agree to the IARC Terms of Use |

> SecuroBox is a utility / media vault → **All Other App Types**
> (not Game, not Social or Communication).

---

## Screen 2 — Questionnaire (exact questions, in order)

**Key principle:** almost every content question explicitly states *"this does not refer
to user-generated content."* The files a user imports into SecuroBox are user-generated,
so they never count toward the rating. Result: **every answer is No.**

| # | Question (paraphrased) | Answer |
|---|---|---|
| 1 | **Downloaded App** — ratings-relevant content (sex/violence/language) shipped in the app package (code/assets)? | **No** |
| 2 | **User Content Sharing** — does the app natively let users interact or exchange content with *other users* via voice/text/images/audio? | **No** |
| 3 | **Online Content** — does the app *feature or promote* content not in the initial download but accessible from the app (Netflix/Amazon/Spotify/AI-generated/NYT style)? | **No** (see note A) |
| 4 | **Violence** — can the app contain violent material (catalog content, not user-generated)? | **No** (see note B) |
| 5 | **Sexuality** — sexual material or nudity (except natural/scientific), catalog content? | **No** |
| 6 | **Language** — potentially offensive language (not user-generated)? | **No** |
| 7 | **Controlled Substance** — references to/depictions of illegal or recreational drugs (catalog)? | **No** |
| 8 | **Age-Restricted Products** — does the app focus on promoting/selling cigarettes, alcohol, firearms, or gambling? | **No** |
| 9a | **Miscellaneous** — shares the user's current & precise physical location with other users? | **No** |
| 9b | — allows users to purchase digital goods? | **No** |
| 9c | — includes cash rewards, gift cards, play-to-earn, convertible crypto rewards, or transferable digital assets (NFTs)? | **No** |
| 9d | — is the app a web browser or search engine? | **No** (see note C) |
| 9e | — is the app primarily a news or educational product? | **No** |

### Note A — "Online Content" (#3) — the URL-download feature
SecuroBox has a "paste a URL to download a file into the vault" feature, so this question
deserves a moment. Answer **No**, honestly: the question targets apps that *feature or
promote* content — a catalog, feed, store, or stream (their own examples: Netflix, Amazon,
Spotify, AI generation, NYT). SecuroBox has no catalog, browse, search, or recommendation
— just a blank field where the user pastes a link to a file they already know about. The
app never surfaces or promotes any content. → **No.**
> Future apps: if your app surfaces a feed/catalog/search of online content, answer **Yes**
> (it will then ask follow-ups about content moderation).

### Note B — "Violence" sub-questions (#4)
Selecting **Yes** reveals three sub-questions ("Is accessing this the primary purpose?",
"Can it be visually depicted?", "Can it be referred to in text/speech?"). Because we
answer **No**, those stay hidden. Same pattern applies to other sections that branch.

### Note C — "Web browser or search engine?" (#9d)
The URL-download field is **not** a browser — no page navigation, no rendering of arbitrary
web pages, no search. A browser is Chrome/Firefox-style free surfing. → **No.**

---

## Screen 3 — Summary (expected output)

- **Google Play**: Rated for Everyone
- **IARC**: PEGI 3, ESRB Everyone, USK 0+, etc.

Click **Submit** to finalize; the App-content checklist item turns green.

---

## Reusable cheat-sheet for future TABSAP apps

For any **offline / single-user utility, tool, or vault** with no ads, no IAP, no accounts,
and no content catalog → the answer to **every** question above is **No**, yielding
*Rated for Everyone*.

Re-evaluate (some become **Yes**) only if a future app:
- lets users **share/communicate** with each other → #2 Yes (needs moderation + reporting)
- **surfaces a feed/catalog/search** of online content → #3 Yes
- ships **mature content** in the package → #4–#7 as applicable
- **sells digital goods / has rewards / crypto** → #9b / #9c Yes
- **is a real browser or search engine** → #9d Yes
- **is a news or educational product** → #9e Yes
