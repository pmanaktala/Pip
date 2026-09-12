# Pip Privacy Policy

_Last updated: 12 September 2026_

Pip is a mood companion. Your moods are personal, and Pip is built so that they stay that way.

## The short version

- **No accounts.** There is nothing to sign up for.
- **No tracking, no analytics, no ads.** Pip contains no advertising, attribution, analytics, crash-reporting or session-replay SDKs. It does not fingerprint your device and does not use the advertising identifier.
- **No servers.** Pip has no backend. We never receive your mood entries, notes, pet name or anything else.
- **Your data lives with you.** Everything is stored on your device and, if you use iCloud, in *your private* iCloud database that only you can access.

## What Pip stores

| Data | Where | Why |
| --- | --- | --- |
| Mood entries (mood, intensity, optional context, optional note, time) | On device; mirrored to your private iCloud database via CloudKit when iCloud is available | So your history is yours and survives reinstalling the app or getting a new phone |
| Pet choice, name and customisation | On device; mirrored to your private iCloud database | So your pet comes back with you |
| Preferences (Health sync, notifications, sound, haptics) | On device only | Permissions are per device |
| A small "current pet state" snapshot | On device, in the app's shared container | So widgets and Live Activities can draw the pet without opening your history |

Pip does not store location, contacts, photos, health data it did not write, or anything else.

## Apple Health

Apple Health sync is **optional and off by default**. If you turn it on, Pip asks Apple for permission to **write** State of Mind entries only. Pip never requests permission to read your Health data, and it only ever reads back the entries it wrote itself (to avoid duplicates after a reinstall).

Turning Health sync off stops new entries. Entries already saved to Health remain in Apple Health — they are yours, and you can manage or delete them in the Health app. Deleting Pip's app data does not delete entries from Apple Health.

Health data is never used for advertising, analytics or profiling, and never leaves your device except through Apple Health's own iCloud sync, which is controlled by you.

## iCloud

Pip uses CloudKit to keep a copy of your mood history and pet in your **private** iCloud database. Only you can access it; the developer cannot read it. If you are not signed into iCloud, Pip still works — your data simply stays on the device and will not survive deleting the app.

## Notifications and Live Activities

Notifications are optional, rare, and never a reminder to log your mood. They are scheduled locally on your device. Live Activities are short, local and end on their own. No push server is involved.

## Deleting your data

Settings › **Delete All App Data** removes your mood history, pet and preferences from your device and from your private iCloud database. Apple Health entries are handled separately, in the Health app, because they belong to Health.

## Children

Pip does not knowingly collect any personal information from anyone, including children, because it collects nothing at all.

## Changes

If this policy changes, the new version will be published at this address and the date above will be updated.

## Contact

Questions: open an issue at https://github.com/pmanaktala/Pip/issues or email manaktala.parth@gmail.com.
