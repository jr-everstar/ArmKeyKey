# Agent instructions

## Releases

When asked to prepare or publish a version, read and follow
[Documentation/ReleaseChecklist.md](Documentation/ReleaseChecklist.md) before making release changes.
Copy [the release record template](Documentation/Releases/TEMPLATE.md) to
`Documentation/Releases/VERSION-publication.md` and keep its evidence and status current.

A release includes documentation, GitHub Release, GitHub Pages and the stable
update feed, and the separate `jr-everstar/homebrew-armkeykey` tap. Do not stop
after uploading a PKG or merging the source. Do not report publication complete
until all required checklist items have evidence; report pending or blocked work explicitly.

The publisher does not update the website HTML, documentation or Homebrew tap,
and its default feed PR still needs merging. It also leaves GitHub's Latest
designation unchanged. Account for all of these in the checklist.

Preserve existing work. Historical version-specific direct-push authorization
does not establish authorization for another release. Follow the current user's
authorized workflow and repository rules; do not ask again for authorization
already supplied. Preparing this checklist alone does not request publication.

Never treat historical manual acceptance or existing readiness booleans as new
test evidence. Never overwrite published assets, retag a release, force-push,
commit credentials/installers, or install/logout on the active account as an
implicit part of packaging.
