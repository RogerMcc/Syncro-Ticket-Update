# Credential exposure response

Audit date: November 5, 2026. Repository: RogerMcc/Syncro-Ticket-Update.

## Evidence and scope

The public, non-archived repository's two legacy files, `Original` and
`Original 2`, were identical. Each contained the same hardcoded RepairTech
TechSuite shop API key at line 17. The startup password was empty; the technician
ID and business label are identifiers, not additional authentication secrets.
The script header date is January 26, 2017, not an exposure timestamp.

All three commits reachable from the cloned main branch were inspected, including
each version of every tracked file, using exact credential matching and review
of credential-like assignments. No other nonempty hardcoded credential was found
in that scope. This was a manual/targeted review, not an exhaustive credential
scanner certification. No key value or reversible fingerprint is recorded here.

| Commit | Author date | Finding |
| --- | --- | --- |
| `186c6c3355c925c3bdac73e749d36ca4aacc59fe` | Dec 4 2021 | LICENSE only |
| `8cadc2df5e667168591329df5df17e6f37394942` | Dec 4 2021 | Key introduced in Original |
| `5b6ceb375e0da08a0eb1a664d44fc54c36805516` | Dec 4 2021 | Same key copied into Original 2 |

These dates establish the first observed committed copy, not when GitHub first
made it public. Hidden refs, deleted branches, private clones, external caches,
service logs, and actual account activity are outside the cloned-history review.
GitHub's public API inventory at audit time returned one branch (`main`), no
tags, no pull requests (open or closed), and no forks; each listing fit on one
page with no continuation. This does not enumerate independent clones or caches.

## Security implications

Treat the key as compromised regardless of age. The script uses it to download
the shop/technician-bound TechSuite executable. Vendor documentation says these
links contain the shop API key and must be treated like passwords. Unauthorized
shop-bound downloads and associated service misuse are credible risks. Broader
report, customer-data, or account access depends on vendor permissions, which
were not verified. This finding alone does not prove access to Syncro, Windows,
the dashboard password, or customer endpoints, and does not prove exploitation.

The service accepts the key in an HTTPS query string, which may also persist in
server or inspecting-proxy logs. Inspect logs and automation copies through
approved administrative channels; do not search the web using the credential.

## Revoke or rotate

Owner: Roger McClelland / ComputeRx. Priority: prompt credential revocation.

1. Use a trusted, authenticated TechSuite Online Dashboard session. Locate the
   shop API key under Settings > App Settings (also called Application Settings
   in older vendor guidance). Do not paste it into chat or a ticket.
2. If an authenticated regeneration/revocation control exists, invalidate the
   exposed shop key and issue a replacement only if the integration is needed.
   If TechSuite is retired, request revocation without replacement. Exact current
   dashboard controls and key validity were not verified by this audit.
3. If no control is available, contact RepairTech through its official support
   page. Request revocation of the historical TechSuite shop API key, confirmation
   that previously issued download links no longer authenticate, the supported
   rotation method, and review of available access/report/configuration logs.
   Provide the account email/dashboard link through their secure channel, not
   the key in public correspondence. No support request was sent by this audit.
4. Store a new key in the protected vault. Update legitimate RMM scripts, task
   configurations, technician download links, and other consumers. Redownload
   account-bound executables if required by RepairTech. Coordinate a brief outage
   rather than keep the exposed key active for convenience.
5. Confirm revocation in the dashboard or with vendor support. If needed, have
   an authorized administrator perform a controlled old-key rejection test without
   logging the URL/key. Validate the new credential and approved executable on a
   test endpoint, check report upload, and review available service activity for
   unrecognized technicians, downloads, reports, integrations, or settings changes.
6. Record the revocation time, vendor confirmation, affected consumers, log review,
   and test outcome in a private operational record. Do not record the secret.

The exposed key is a TechSuite key, not demonstrated to be a Syncro/RepairShopr API
key. Rotate any separate downstream integration key if investigation finds it was
also exposed or misused. Do not assume this change rotates downstream credentials.

## History and prevention

This remediation cleans the current tree without rewriting history. Old commits
remain retrievable. Source cleanup does not revoke authentication.

After revocation, decide whether history removal is still necessary. Coordinate
with collaborators and forks before any force push. Use a fresh mirror and
git-filter-repo's sensitive-data removal workflow to remove both legacy file paths
from old history, preserve the clean replacement, verify all relevant branches
and tags, and coordinate clean reclones. A history rewrite changes commit IDs
and may break links/signatures or discard concurrent work. It is not performed
as part of the ordinary current-source update. Do not copy an old patch into a
new commit, PR description, issue, or support ticket.

GitHub caches, pull-request refs, forks, and independent clones can retain old
objects after a rewrite. Coordinate fork/clone cleanup. Contact GitHub Support
for eligible cache/ref removal; support assistance depends on whether rotation
can mitigate the risk. Do not claim permanent erasure from public distribution.

Review GitHub secret-scanning alerts and push protection in repository settings;
enable available protections and add custom detection for legacy keys if supported.
Do not assume GitHub recognizes the historical TechSuite key format. Add local
secret scanning to the development workflow. Secret scanning settings and alerts
were not verified or changed during this audit.

## Authoritative references

- https://www.repairtechsolutions.com/documentation/integrations/
- https://www.repairtechsolutions.com/documentation/techsuite-for-windows/
- https://www.repairtechsolutions.com/support/
- https://docs.github.com/en/code-security/tutorials/remediate-leaked-secrets/remediating-a-leaked-secret
- https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
