# Content Rating (IARC) — exact answers

Path: **Policy → App content → Content ratings → Start questionnaire**

Choose category: **Reference, News or Educational** (not "Apps"). The Reference flow is the closest match.

Walk through the standard sections answering as below:

| Section | Answer |
|---|---|
| Email address | info@tabsap.com |
| App category | Reference, News or Educational |
| **Violence** — does the app contain any violent imagery? | No |
| **Sexuality** — does it contain sexual content, nudity, or innuendo? | No |
| **Profanity** — strong language? | No |
| **Controlled substances** — drugs, alcohol, tobacco references? | No |
| **Gambling** — real-money gambling or simulated gambling? | No |
| **User interaction** — does the app let users interact with each other (chat, multiplayer, comments)? | **No** (the app is single-user, offline) |
| **Sharing of user location** | No |
| **Personal information sharing** | No |
| **Digital purchases** | No |
| **Mature web content** (browser, embedded webview to arbitrary sites) | No |
| **User-generated content** | **No** — even though users can import their own files, the content is *not shared with other users* |

Expected output rating:
- **IARC**: 3+ (PEGI), Everyone (ESRB), 0+ (USK)
- **Google Play**: Rated for everyone

> ⚠️ Honesty note: the app *can* play any video the user imports, including content they themselves recorded. The IARC questionnaire is about content the **app distributes**, not what users put on their own device. So "No user-generated content" and "No mature content" are correct for this form.

If you ever add a feature where users **share** files with each other, you'll need to re-rate as User-Generated Content and add a content moderation system.
