# Content Rating (IARC) — exact answers

Path: **Policy and programs → App content → Content ratings → Start questionnaire**

## Screen 1 — Category

The current Play Console flow offers only **three** top-level categories (Google retired
the old "Reference / News / Educational" sub-list). Pick the third:

| Field | Answer |
|---|---|
| Email address | info@tabsap.com |
| Category | **All Other App Types** |
| Terms | ☑ Agree to the IARC Terms of Use |

> SecuroBox is a utility / media vault, so it falls under **All Other App Types**
> (not Game, not Social or Communication).

## Screen 2 — Questionnaire

For SecuroBox every answer is **No**:

| Section | Question | Answer |
|---|---|---|
| Violence | Violent imagery / references to violence? | No |
| Sexuality | Sexual content, nudity, or suggestive material? | No |
| Language | Profanity or crude humor? | No |
| Controlled substances | Drugs, alcohol, tobacco references? | No |
| Miscellaneous — Gambling | Real-money or simulated gambling? | No |
| Miscellaneous — User location | Shares the user's physical location with other users? | No |
| Miscellaneous — User interaction | Users can interact / communicate / exchange content? | **No** (single-user, offline) |
| Miscellaneous — Digital purchases | Can users buy digital goods? | No |
| Miscellaneous — Browser / search | Is the app a web browser or search engine? | **No** (see note) |

### ⚠️ "Is this a web browser or search engine?"

SecuroBox has a "paste a URL to download a file into the vault" feature. This is **not**
a browser — no page navigation, no rendering of arbitrary web pages, no search. **No is
correct and honest.** A browser is Chrome/Firefox-style free surfing.

### Note on user-generated / mature content

There is **no** "user-generated content" or "mature content" toggle in the *All Other
App Types* questionnaire. Those concepts live in the separate **Data Safety** form and the
**Target audience and content** checklist item — not here. Even though users can import
their own files, that content is never shared with other users, so it does not change this
rating.

## Screen 3 — Summary (expected output)

- **Google Play**: Rated for Everyone
- **IARC**: PEGI 3, ESRB Everyone, USK 0+, etc.

Click **Submit** to lock it in; the checklist item turns green.

---

> If you ever add a feature where users **share** files with each other, you'll need to
> re-rate (answer **Yes** to user interaction) and add a content-moderation / reporting
> system, per Google policy.
