# Waypoint v0.22.1 — GitHub Setup Hotfix

- Fixed fresh-repository setup on Windows PowerShell.
- Replaced the failing `git remote get-url origin` probe with non-failing `git remote` discovery.
- Preserves existing local commits and supports rerunning setup after the original v0.22 failure.
